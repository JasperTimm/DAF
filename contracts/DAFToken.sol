// SPDX-License-Identifier: MIT

pragma solidity >=0.7.5;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/ERC20Snapshot.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol';
import './DAFVoting.sol';

contract DAFToken is ERC20Snapshot {

    using EnumerableSet for EnumerableSet.UintSet;

    uint256 constant public SHARE_FACTOR = 1e8;
    uint256 constant public BUY_SLIP_FACTOR = 110000000;
    uint32 constant public TWAP_PERIOD = 60; // 1 minute

    DAFVoting public dafVoting;

    struct Holding{
        ERC20 tokenAddr;
        uint256 holdingShare;
        address swapPool;
    }

    uint256 holdingIndex;
    EnumerableSet.UintSet private holdingSet;
    mapping(uint256 => Holding) public holdingMap;
    ERC20 public stableToken;
    uint256 stableTokenShare;

    ISwapRouter public constant uniswapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    constructor(string memory _name, string memory _symbol, address _stableToken) ERC20(_name, _symbol) {
        stableToken = ERC20(_stableToken);
        stableTokenShare = 1 * SHARE_FACTOR;
        dafVoting = new DAFVoting(address(this));
    }

    function buy(uint256 _stableAmt) external payable {
        stableToken.transferFrom(msg.sender, address(this), _stableAmt);
        //Need to work out current token price in stable and only mint that amount
        uint256 mintAmt = totalSupply() == 0 ? (_stableAmt * 10 ** decimals()) / (10 ** stableToken.decimals()) : (_stableAmt * totalSupply()) / totalValInStable();
        _mint(msg.sender, mintAmt);
    }

    function sellStable() external {
        //TODO: Try to send msg.sender's share based on holding prices in stableToken without swaps
    }

    function sellSwap() external {
        //swap msg.sender's share of each holding to stableToken and transfer final amount
        //TODO: Sell only a proportion of msg.sender's tokens?
        uint256 senderAmt = balanceOf(msg.sender);
        _burn(msg.sender, senderAmt);
        stableToken.transfer(msg.sender, (stableToken.balanceOf(address(this)) * senderAmt) / totalSupply());
        uint256 stableProceeds = 0; 
        for (uint i=0; i < holdingSet.length(); i++) {
            stableProceeds += sellToken(i, (holdingMap[holdingSet.at(i)].tokenAddr.balanceOf(address(this)) * senderAmt) / totalSupply());
        }
        stableToken.transfer(msg.sender, stableProceeds);        
    }

    //buy a certain amt of tokenAddr with stableToken
    //amt is given in stable
    function buyToken(uint256 _holdingId, uint256 _stableAmt) internal returns(uint256 holdingAmt) {
        stableToken.approve(address(uniswapRouter), _stableAmt);
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(stableToken),
                tokenOut: address(holdingMap[_holdingId].tokenAddr),
                fee: IUniswapV3Pool(holdingMap[_holdingId].swapPool).fee(),
                recipient: address(this),
                deadline: block.timestamp + 3600,
                amountIn: _stableAmt,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        holdingAmt = uniswapRouter.exactInputSingle(params);
    }

    //sell a certain amt of tokenAddr for stableToken
    function sellToken(uint256 _holdingId, uint256 _holdingAmt) internal returns(uint256 stableAmt) {
        holdingMap[_holdingId].tokenAddr.approve(address(uniswapRouter), _holdingAmt);
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(holdingMap[_holdingId].tokenAddr),
                tokenOut: address(stableToken),
                fee: IUniswapV3Pool(holdingMap[_holdingId].swapPool).fee(),
                recipient: address(this),
                deadline: block.timestamp + 3600,
                amountIn: _holdingAmt,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        stableAmt = uniswapRouter.exactInputSingle(params);
    }

    function sellTransfer() external {
        //transfer msg.sender's share of stableToken and each Holding
        //TODO: Sell only a proportion of msg.sender's tokens?
        uint256 senderAmt = balanceOf(msg.sender);
        _burn(msg.sender, senderAmt);
        stableToken.transfer(msg.sender, (stableToken.balanceOf(address(this)) * senderAmt) / totalSupply()); 
        for (uint i=0; i < holdingSet.length(); i++) {
            holdingMap[i].tokenAddr.transfer(msg.sender, (holdingMap[holdingSet.at(i)].tokenAddr.balanceOf(address(this)) * senderAmt) / totalSupply());
        }
    }

    function updateHolding(uint256 _holdingId, uint256 _holdingShare) external onlyDAFVoting {
        require(holdingSet.contains(_holdingId), "Invalid index for _holdingId");
        require(_holdingShare >= 0 && _holdingShare <= 1 * SHARE_FACTOR, "Invalid _holdingShare, must be between 0 and 1");
        require(stableTokenShare - (_holdingShare - holdingMap[_holdingId].holdingShare) > 0, "Not enough stableToken to increase holding");
        
        stableTokenShare = stableTokenShare - (_holdingShare - holdingMap[_holdingId].holdingShare);
        holdingMap[_holdingId].holdingShare = _holdingShare;
        rebalance();
        if (_holdingShare == 0) {
            delete holdingMap[_holdingId];
            holdingSet.remove(_holdingId);
        }
    }

    function newHolding(Holding memory _holding) external onlyDAFVoting {
        //TODO: This will need to add a bunch of things with the tokenAddr, share: price lookup contract address, maybe other things
        require(_holding.holdingShare >= 0 && _holding.holdingShare <= 1 * SHARE_FACTOR, "Invalid _holdingShare, must be between 0 and 1");
        require(stableTokenShare - _holding.holdingShare > 0, "Not enough stableToken to add new holding");        
        for (uint i=0; i < holdingSet.length(); i++) {
            if (holdingMap[holdingSet.at(i)].tokenAddr == _holding.tokenAddr) {
                require(false, "_tokenAddr already exists in holdings, use updateHolding");
            }            
        }
        holdingMap[holdingIndex] = _holding;
        holdingSet.add(holdingIndex);
        holdingIndex++;
        rebalance();
    }

    function swapHolding(ERC20 _tokenAddr1, uint256 _holdingShare1, ERC20 _tokenAddr2, uint256 _holdingShare2) external {
        //swap one token for another directly if it exists, otherwise via stableToken swaps
        //TODO: Need to rethink a more efficient way of doing this given a rebalance with many swaps
    }

    //Rebalances fund based on holding price changes, calling is scheduled periodically (randomly)?
    //TODO: A lot of ways to rebalance. For now we'll simply make this a rebalance based on target share holding.
    // In the future, having % corridors before selling would work better. 
    function rebalance() public {
        uint256 totalVal = totalValInStable();
        for (uint i=0; i < holdingSet.length(); i++) {
            uint256 expValStable = (totalVal * holdingMap[holdingSet.at(i)].holdingShare) / SHARE_FACTOR;
            uint256 curValStable = holdingToStable(i, holdingMap[i].tokenAddr.balanceOf(address(this)));
            if (curValStable < expValStable) {
                buyToken(i, expValStable - curValStable);
            } else if (curValStable > expValStable) {
                sellToken(i, stableToHolding(i, curValStable - expValStable));
            } else {
                continue;
            }
        }
    }

    function totalValInStable() public view returns (uint256) {
        uint256 totalVal = stableToken.balanceOf(address(this));
        for (uint i=0; i < holdingSet.length(); i++) {
            totalVal += holdingToStable(i, holdingMap[holdingSet.at(i)].tokenAddr.balanceOf(address(this)));
        }
        return totalVal;
    }

    // To keep large volumes of holdings from affecting price too much we simply look at the price 
    // of 1 stableToken in the given holding.
    //TODO: Should find a way to cache this
    function oneStableAmt(uint256 _holdingId) public view returns (uint256) {
        int24 tick = OracleLibrary.consult(holdingMap[_holdingId].swapPool, TWAP_PERIOD);
        uint256 quoteAmt = OracleLibrary.getQuoteAtTick(tick, uint128(1 * 10 ** stableToken.decimals()), address(stableToken), address(holdingMap[_holdingId].tokenAddr));
        return quoteAmt;
    }

    function holdingToStable(uint256 _holdingId, uint256 _holdingAmt) public view returns (uint256 stableAmt) {
        stableAmt = (_holdingAmt * 10 ** stableToken.decimals()) / oneStableAmt(_holdingId);
    }

    function stableToHolding(uint256 _holdingId, uint256 _stableAmt) public view returns (uint256 holdingAmt) {
        holdingAmt = (_stableAmt * oneStableAmt(_holdingId)) / (10 ** stableToken.decimals());
    }

    function snapshot() onlyDAFVoting public returns (uint256) {
        return _snapshot();
    } 

    modifier onlyDAFVoting() {
        require(msg.sender == address(dafVoting), "This function can only be called by DAFVoting");
        _;
    }
}