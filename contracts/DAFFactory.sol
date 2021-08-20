// SPDX-License-Identifier: MIT

pragma solidity >=0.7.5;
pragma abicoder v2;

import './DAFToken.sol';

contract DAFFactory {

    DAFToken[] public tokenList;

    event DAFTokenCreated (
        address tokenAddr
    );

    function createDAFToken(string memory _name, string memory _symbol, address _stableToken) public {
        DAFToken newToken = new DAFToken(_name, _symbol, _stableToken);
        tokenList.push(newToken);
        emit DAFTokenCreated(address(newToken));
    }
}