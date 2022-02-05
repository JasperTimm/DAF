// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.5;
pragma abicoder v2;

import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/interfaces/IQuoter.sol';
import '@uniswap/v3-periphery/contracts/SwapRouter.sol';
import '../interfaces/IOracle.sol';
import '@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol';
import '@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol';
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ProxySwapRouter is ISwapRouter, IOracle {

    // Actual uniswapV3Router
    SwapRouter public constant uniswapRouter = SwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    // Not efficient to use on-chain but this contract is specifically for a test chain 
    IQuoter public constant quoter = IQuoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);
    uint32 constant public TWAP_PERIOD = 60; // 1 minute

    mapping(address => int24) public mainnetTicks;
    address[] public swapPools;
    address public oracle;

    constructor() {
        oracle = msg.sender;
    }

    function swapPoolsLength() external view returns(uint) {
        return swapPools.length;
    }

    function getSwapPools() external view returns(address[] memory) {
        return swapPools;
    }

    function addSwapPool(address _swapPool, int24 _initialTick) external onlyOracle {
        swapPools.push(_swapPool);
        mainnetTicks[_swapPool] = _initialTick;
    }

    function updateTicks(address[] calldata _swapPools, int24[] calldata _newTicks) external onlyOracle {
        for (uint i=0; i<_swapPools.length; i++) {
            mainnetTicks[_swapPools[i]] = _newTicks[i];
        }
    }

    function getPoolAddress(
        address tokenA,
        address tokenB,
        uint24 fee        
    ) private view returns (address) {
        return PoolAddress.computeAddress(uniswapRouter.factory(), PoolAddress.getPoolKey(tokenA, tokenB, fee));
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another token
    /// @param params The parameters necessary for the swap, encoded as `ExactInputSingleParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInputSingle(ExactInputSingleParams calldata params) override external payable returns (uint256) {
        ERC20 tokenIn = ERC20(params.tokenIn);
        ERC20 tokenOut = ERC20(params.tokenOut);        
        address swapPool = getPoolAddress(params.tokenIn, params.tokenOut, params.fee);
        uint256 mainnetAmtOut = OracleLibrary.getQuoteAtTick(getTick(swapPool, TWAP_PERIOD), uint128(params.amountIn), params.tokenIn, params.tokenOut);
        //Subtract fee from this
        mainnetAmtOut -= (mainnetAmtOut * params.fee) / 1e6;

        // What do we need to satisfy the mainnet out requirement
        uint256 reqInAmt = quoter.quoteExactOutputSingle(params.tokenIn, params.tokenOut, params.fee, mainnetAmtOut, params.sqrtPriceLimitX96);
        tokenIn.transferFrom(msg.sender, address(this), params.amountIn);

        uint256 amtIn = reqInAmt > tokenIn.balanceOf(address(this)) ? tokenIn.balanceOf(address(this)) : reqInAmt;
        ExactInputSingleParams memory ourParams = params;
        ourParams.recipient = address(this);
        ourParams.amountIn = amtIn;

        tokenIn.approve(address(uniswapRouter), params.amountIn);
        uint256 amtOut = uniswapRouter.exactInputSingle(ourParams);

        // If we didn't quite make the amt, try to top it up
        if (amtOut < mainnetAmtOut && tokenOut.balanceOf(address(this)) >= mainnetAmtOut) {
            amtOut = mainnetAmtOut;
        }

        tokenOut.transfer(msg.sender, amtOut);
        return amtOut;
    }

    /// @notice Fetches time-weighted average tick by using the stored ticks from the oracle
    /// @param pool Address of Uniswap V3 pool that we want to observe
    /// @return timeWeightedAverageTick The time-weighted average tick 
    function getTick(address pool, uint32 period) override public view returns (int24) {
        if (mainnetTicks[pool] == 0) {
            //Falling back to swapPool's price here if we haven't got price data from the oracle
            (int24 tick, ) = OracleLibrary.consult(pool, period);
            return tick;
        } else {
            return mainnetTicks[pool];
        }
    }

    // NOT IMPLEMENTED

    function exactInput(ExactInputParams calldata) override external payable returns (uint256) {
        require(false, "Not implemented");
        return 0;  
    }

    function exactOutputSingle(ExactOutputSingleParams calldata) override external payable returns (uint256) {
        require(false, "Not implemented");
        return 0;  
    }

    function exactOutput(ExactOutputParams calldata) override external payable returns (uint256) {
        require(false, "Not implemented");
        return 0;
    }

    function uniswapV3SwapCallback(
        int256,
        int256,
        bytes calldata
    ) override external pure {
        require(false, "Not implemented");
    }

    modifier onlyOracle() {
        require(msg.sender == oracle, "This function can only be called by oracle");
        _;
    }    
}