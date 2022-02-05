// SPDX-License-Identifier: MIT

pragma solidity >=0.7.5;
pragma abicoder v2;

import './DAFToken.sol';

contract DAFFactory {

    DAFToken[] public tokenList;

    address public router;
    address public oracle;

    event DAFTokenCreated (
        address tokenAddr
    );

    constructor(address _router, address _oracle) {
        router = _router;
        oracle = _oracle;
    }

    function createDAFToken(string memory _name, string memory _symbol, address _stableToken) public {
        DAFToken newToken = new DAFToken(_name, _symbol, _stableToken, router, oracle);
        tokenList.push(newToken);
        emit DAFTokenCreated(address(newToken));
    }

    function getAllTokens() public view returns (DAFToken[] memory) {
        return tokenList;
    }

    function getTokenCount() public view returns (uint) {
        return tokenList.length;
    }
}