// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";

contract DAFToken is ERC20Votes {

    uint256 constant public SHARE_DECIMAL = 1e8;

    struct Holding{
        ERC20 tokenAddr;
        uint256 holdingShare;
        uint256 priceInStable;
        //TODO: A contract which allows for a price lookup priceInStable for each token
    }

    Holding[] public holdings;
    ERC20 public stableToken;
    uint256 stableTokenShare;

    constructor(string memory _name, string memory _symbol, address _stableToken) ERC20(_name, _symbol) ERC20Permit(_name) {
        stableToken = ERC20(_stableToken);
        stableTokenShare = 1 * SHARE_DECIMAL;
    }

    function buy(uint256 _amt) external payable {
        //buy tokens
        stableToken.transferFrom(msg.sender, address(this), _amt);
        _mint(msg.sender, _amt);
    }

    function sellStable() external {
        //TODO: Try to send msg.sender's share based on holding prices in stableToken without swaps
    }

    function sellSwap() external {
        //swap msg.sender's share of each holding to stableToken and transfer final amount
        //TODO: Sell only a proportion of msg.sender's tokens?
        uint256 senderShare = balanceOf(msg.sender);
        _burn(msg.sender, senderShare);
        stableToken.transfer(msg.sender, (stableToken.balanceOf(address(this)) * senderShare) / totalSupply());
        uint256 initStableBalance = stableToken.balanceOf(address(this)); 
        for (uint i=0; i < holdings.length; i++) {
            sellToken(holdings[i].tokenAddr, (holdings[i].tokenAddr.balanceOf(address(this)) * senderShare) / totalSupply());
        }
        stableToken.transfer(msg.sender, stableToken.balanceOf(address(this)) - initStableBalance);        
    }

    //sell a certain amt of tokenAddr for stableToken
    function sellToken(ERC20 tokenAddr, uint256 amt) internal {

    }

    //buy a certain amt of tokenAddr with stableToken
    function buyToken(ERC20 tokenAddr, uint256 amt) internal {

    }

    function sellTransfer() external {
        //transfer msg.sender's share of stableToken and each Holding
        //TODO: Sell only a proportion of msg.sender's tokens?
        uint256 senderShare = balanceOf(msg.sender);
        _burn(msg.sender, senderShare);
        stableToken.transfer(msg.sender, (stableToken.balanceOf(address(this)) * senderShare) / totalSupply()); 
        for (uint i=0; i < holdings.length; i++) {
            holdings[i].tokenAddr.transfer(msg.sender, (holdings[i].tokenAddr.balanceOf(address(this)) * senderShare) / totalSupply());
        }
    }

    function updateHolding(uint256 _holdingId, uint256 _holdingShare) external {
        require(_holdingId >= 0 && _holdingId < holdings.length, "Invalid index for _holdingId");
        require(_holdingShare >= 0 && _holdingShare <= 1 * SHARE_DECIMAL, "Invalid _holdingShare, must be between 0 and 1");
        require(stableTokenShare - (_holdingShare - holdings[_holdingId].holdingShare) > 0, "Not enough stableToken to increase holding");
        
        stableTokenShare = stableTokenShare - (_holdingShare - holdings[_holdingId].holdingShare);
        holdings[_holdingId].holdingShare = _holdingShare;
        rebalance();
        if (_holdingShare == 0) {
            delete holdings[_holdingId];
        }
    }

    function newHolding(ERC20 _tokenAddr, uint256 _holdingShare /* contract for price updates */) external {
        //TODO: This will need to add a bunch of things with the tokenAddr, share: price lookup contract address, maybe other things
        require(_holdingShare >= 0 && _holdingShare <= 1 * SHARE_DECIMAL, "Invalid _holdingShare, must be between 0 and 1");
        require(stableTokenShare - _holdingShare > 0, "Not enough stableToken to add new holding");        
        for (uint i=0; i < holdings.length; i++) {
            if (holdings[i].tokenAddr == _tokenAddr) {
                require(false, "_tokenAddr already exists in holdings, use updateHolding");
            }            
        }
        holdings.push(Holding(_tokenAddr, _holdingShare, 1));
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
        for (uint i=0; i < holdings.length; i++) {
            uint256 expVal = (totalVal * holdings[i].holdingShare) / SHARE_DECIMAL;
            uint256 curVal = holdings[i].tokenAddr.balanceOf(address(this)) * holdings[i].priceInStable;
            if (curVal < expVal) {
                buyToken(holdings[i].tokenAddr, expVal - curVal);
            } else if (curVal > expVal) {
                sellToken(holdings[i].tokenAddr, curVal - expVal);
            } else {
                continue;
            }
        }
    }

    function totalValInStable() public view returns (uint256) {
        uint256 totalVal = stableToken.balanceOf(address(this));
        for (uint i=0; i < holdings.length; i++) {
            totalVal += holdings[i].tokenAddr.balanceOf(address(this)) * holdings[i].priceInStable;
        }
        return totalVal;
    }

    function tokenPriceInStable() public view returns (uint256) {
        return totalValInStable() / totalSupply();
    }

}