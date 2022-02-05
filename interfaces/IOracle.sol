// SPDX-License-Identifier: MIT

pragma solidity >=0.7.5;
pragma abicoder v2;

interface IOracle {

    //Gets the latest tick for a pool, similar to OracleLibrary.consult
    function getTick(address pool, uint32 period) external view returns (int24 timeWeightedAverageTick);
}