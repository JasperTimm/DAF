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
    uint256 constant public IMMED_SELL_FACTOR = SHARE_FACTOR / 10;
    uint32 constant public TWAP_PERIOD = 60; // 1 minute

    DAFVoting public dafVoting;

    struct Holding{
        ERC20 token;
        uint256 holdingShare;
        address swapPool;
    }

    uint256 public holdingIndex;
    EnumerableSet.UintSet private holdingSet;
    mapping(uint256 => Holding) public holdingMap;
    ERC20 public stableToken;
    uint256 public stableTokenShare;

    ISwapRouter public constant uniswapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    constructor(string memory _name, string memory _symbol, address _stableToken) ERC20(_name, _symbol) {
        stableToken = ERC20(_stableToken);
        stableTokenShare = 1 * SHARE_FACTOR;
        dafVoting = new DAFVoting(address(this));
    }

    function getAllHoldings() public view returns(Holding[] memory) {
        Holding[] memory holdings = new Holding[](holdingSet.length());
        for (uint setId=0; setId < holdings.length; setId++) {
            holdings[setId] = holdingMap[holdingSet.at(setId)];
        }

        return holdings;
    }

    function holdingAddr(uint _setId) public view returns(address) {
        return address(holdingMap[holdingSet.at(_setId)].token);
    }

    function holdingBal(uint _setId) public view returns(uint256) {
        return holdingMap[holdingSet.at(_setId)].token.balanceOf(address(this));
    }

    function buy(uint256 _tokenAmt) external payable {
        require(_tokenAmt > 0, "Cannot buy zero");
        stableToken.transferFrom(msg.sender, address(this), convertToStableAmt(_tokenAmt));
        _mint(msg.sender, _tokenAmt);
    }

    function sell(uint256 _tokenAmt) external {
        require(_tokenAmt > 0, "Cannot sell zero");
        require(balanceOf(msg.sender) >= _tokenAmt, "You don't have that many tokens to sell");
        //If amtInStable is small enough, simply send the equivalent in stable and wait for a rebalance
        //TODO: Still not a great solution, someone can continually pull this amount out till it's all gone
        uint256 amtInStable = convertToStableAmt(_tokenAmt);
        if (amtInStable / stableToken.balanceOf(address(this)) < IMMED_SELL_FACTOR / SHARE_FACTOR) {
            _burn(msg.sender, _tokenAmt);
            stableToken.transfer(msg.sender, amtInStable);
        } else {
            //Otherwise swap msg.sender's share of each holding to stableToken and transfer final amount
            uint256 stableProceeds = stableToken.balanceOf(address(this)) * _tokenAmt / totalSupply(); 
            for (uint setId=0; setId < holdingSet.length(); setId++) {
                stableProceeds += sellToken(setId, holdingBal(setId) * _tokenAmt / totalSupply());
            }
            _burn(msg.sender, _tokenAmt);
            stableToken.transfer(msg.sender, stableProceeds);        
        }
    }

    //buy a certain amt of tokenAddr with stableToken
    //amt is given in stable
    function buyToken(uint256 _setId, uint256 _stableAmt) internal returns(uint256 holdingAmt) {
        stableToken.approve(address(uniswapRouter), _stableAmt);
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: address(stableToken),
                tokenOut: holdingAddr(_setId),
                fee: IUniswapV3Pool(holdingMap[holdingSet.at(_setId)].swapPool).fee(),
                recipient: address(this),
                deadline: block.timestamp + 3600,
                amountIn: _stableAmt,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        holdingAmt = uniswapRouter.exactInputSingle(params);
    }

    //sell a certain amt of tokenAddr for stableToken
    function sellToken(uint256 _setId, uint256 _holdingAmt) internal returns(uint256 stableAmt) {
        holdingMap[holdingSet.at(_setId)].token.approve(address(uniswapRouter), _holdingAmt);
        ISwapRouter.ExactInputSingleParams memory params =
            ISwapRouter.ExactInputSingleParams({
                tokenIn: holdingAddr(_setId),
                tokenOut: address(stableToken),
                fee: IUniswapV3Pool(holdingMap[holdingSet.at(_setId)].swapPool).fee(),
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
        for (uint setId=0; setId < holdingSet.length(); setId++) {
            holdingMap[holdingSet.at(setId)].token.transfer(msg.sender, (holdingBal(setId) * senderAmt) / totalSupply());
        }
    }

    function existingShare(address _tokenAddr) public view returns(uint256) {
        uint256 share = 0;
        for (uint setId=0; setId < holdingSet.length(); setId++) {
            if (holdingAddr(setId) == _tokenAddr) {
                share = holdingMap[holdingSet.at(setId)].holdingShare;
            }            
        }        
        return share;
    }

    function checkValidHoldingChange(Holding memory _holding) external view returns(bool) {
        uint256 existing = existingShare(address(_holding.token));
        return (
            _holding.holdingShare <= 1 * SHARE_FACTOR &&
            _holding.holdingShare != existing &&
            stableTokenShare - (_holding.holdingShare - existing) > 0);
    }

    function changeHolding(Holding memory _holding) external onlyDAFVoting {
        uint256 existingId = 0;
        bool exists = false;
        for (uint setId=0; setId < holdingSet.length(); setId++) {
            if (holdingAddr(setId) == address(_holding.token)) {
                existingId = holdingSet.at(setId);
                exists = true;
            }            
        }

        if (!exists) {
            stableTokenShare = stableTokenShare - _holding.holdingShare;
            holdingMap[holdingIndex] = _holding;
            holdingSet.add(holdingIndex);
            holdingIndex++;
        } else {
            stableTokenShare = stableTokenShare - (_holding.holdingShare - holdingMap[existingId].holdingShare);
            holdingMap[existingId].holdingShare = _holding.holdingShare;
        }

        rebalance();

        if (_holding.holdingShare == 0) {
            delete holdingMap[existingId];
            holdingSet.remove(existingId);
        }        
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
        for (uint setId=0; setId < holdingSet.length(); setId++) {
            uint256 expValStable = (totalVal * holdingMap[holdingSet.at(setId)].holdingShare) / SHARE_FACTOR;
            uint256 curValStable = holdingToStable(setId);
            if (curValStable < expValStable) {
                buyToken(setId, expValStable - curValStable);
            } else if (curValStable > expValStable) {
                sellToken(setId, stableToHolding(setId, curValStable - expValStable));
            } else {
                continue;
            }
        }
    }

    function totalValInStable() public view returns (uint256) {
        uint256 totalVal = stableToken.balanceOf(address(this));
        for (uint setId=0; setId < holdingSet.length(); setId++) {
            totalVal += holdingToStable(setId);
        }
        return totalVal;
    }

    function convertToTokenAmt(uint256 _stableAmt) public view returns (uint256) {
        if (totalSupply() == 0) {
            return ( (_stableAmt * (10 ** decimals())) / 10 ** stableToken.decimals() );
        } else {
            return ( (_stableAmt * totalSupply()) / totalValInStable() );
        }
    }

    function convertToStableAmt(uint256 _tokenAmt) public view returns (uint256) {
        if (totalSupply() == 0) {
            return ( (_tokenAmt * (10 ** stableToken.decimals())) / 10 ** decimals() );
        } else {
            return ( (_tokenAmt * totalValInStable()) / totalSupply() );
        }
    }

    // To keep large volumes of holdings from affecting price too much we simply look at the price 
    // of 1 stableToken in the given holding.
    //TODO: Should find a way to cache this
    function oneStableAmt(uint256 _setId) public view returns (uint256) {
        int24 tick = OracleLibrary.consult(holdingMap[holdingSet.at(_setId)].swapPool, TWAP_PERIOD);
        uint256 quoteAmt = OracleLibrary.getQuoteAtTick(tick, uint128(1 * 10 ** stableToken.decimals()), address(stableToken), holdingAddr(_setId));
        return quoteAmt;
    }

    function holdingToStable(uint256 _setId) public view returns (uint256 stableAmt) {
        stableAmt = (holdingBal(_setId) * 10 ** stableToken.decimals()) / oneStableAmt(_setId);
    }

    function stableToHolding(uint256 _setId, uint256 _stableAmt) public view returns (uint256 holdingAmt) {
        holdingAmt = (_stableAmt * oneStableAmt(_setId)) / (10 ** stableToken.decimals());
    }

    function snapshot() onlyDAFVoting public returns (uint256) {
        return _snapshot();
    } 

    modifier onlyDAFVoting() {
        require(msg.sender == address(dafVoting), "This function can only be called by DAFVoting");
        _;
    }
}