// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { ERC20 } from 'contracts/dependencies/openzeppelin/contracts/ERC20.sol';

import { IBaseSwap } from 'contracts/interfaces/IBaseSwap.sol';

import { IQuoter } from 'contracts/interfaces/external/uniswap-v3/IQuoter.sol';
import { IAutoRouter } from 'contracts/interfaces/external/uniswap-v3/IAutoRouter.sol';
import { IUniswapV3Pool } from 'contracts/interfaces/external/uniswap-v3/IUniswapV3Pool.sol';
import { IUniswapV3Factory } from 'contracts/interfaces/external/uniswap-v3/IUniswapV3Factory.sol';

contract UniswapHelper {
    uint24 internal constant FEE_LOW = 500;
    uint24 internal constant FEE_MEDIUM = 3000;
    uint24 internal constant FEE_HIGH = 10000;

    IUniswapV3Factory internal constant UNISWAP_FACTORY = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    IQuoter internal constant QUOTER = IQuoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);

    function getMulticalSwapData(
        address _fromToken,
        address _toToken,
        address _recipient,
        uint256 _amount
    ) public view returns (bytes memory) {
        bytes[] memory _calldata = new bytes[](1);
        _calldata[0] = getExactInputData(_fromToken, _toToken, _recipient, _amount, 0);
        return abi.encodeWithSelector(IAutoRouter.multicall.selector, block.timestamp + 10 days, _calldata);
    }

    function getExactInputData(
        address _tokenIn,
        address _tokenOut,
        address _recipient,
        uint256 _amountIn,
        uint256 _minReceiveAmount
    ) public view returns (bytes memory) {
        bytes memory path = _getPath(_tokenIn, _tokenOut, address(0));
        IAutoRouter.ExactInputParams memory params = IAutoRouter.ExactInputParams(
            path,
            _recipient,
            _amountIn,
            _minReceiveAmount
        );

        return abi.encodeWithSelector(IAutoRouter.exactInput.selector, params);
    }

    function quoteExactInput(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        address _hopToken
    ) public returns (uint256 amountOut) {
        bytes memory path = _getPath(_tokenIn, _tokenOut, _hopToken);
        amountOut = QUOTER.quoteExactInput(path, _amountIn);
    }

    function _getPath(address _tokenIn, address _tokenOut, address _hopToken) private view returns (bytes memory path) {
        if (_hopToken == address(0) || _tokenIn == _hopToken || _tokenOut == _hopToken) {
            (, uint24 fee) = _getUniswapPool(_tokenIn, _tokenOut);
            path = abi.encodePacked(_tokenIn, fee, _tokenOut);
        } else {
            (, uint24 fee0) = _getUniswapPool(_tokenIn, _hopToken);
            (, uint24 fee1) = _getUniswapPool(_tokenOut, _hopToken);
            path = abi.encodePacked(_tokenIn, fee0, _hopToken, fee1, _tokenOut);
        }
    }

    function _getUniswapPool(
        address _tokenIn,
        address _tokenOut
    ) private view returns (IUniswapV3Pool pool, uint24 fee) {
        IUniswapV3Pool poolLow = IUniswapV3Pool(UNISWAP_FACTORY.getPool(_tokenIn, _tokenOut, FEE_LOW));
        IUniswapV3Pool poolMedium = IUniswapV3Pool(UNISWAP_FACTORY.getPool(_tokenIn, _tokenOut, FEE_MEDIUM));
        IUniswapV3Pool poolHigh = IUniswapV3Pool(UNISWAP_FACTORY.getPool(_tokenIn, _tokenOut, FEE_HIGH));

        uint128 liquidityLow = address(poolLow) != address(0) ? poolLow.liquidity() : 0;
        uint128 liquidityMedium = address(poolMedium) != address(0) ? poolMedium.liquidity() : 0;
        uint128 liquidityHigh = address(poolHigh) != address(0) ? poolHigh.liquidity() : 0;
        if (liquidityLow > liquidityMedium && liquidityLow >= liquidityHigh) {
            return (poolLow, FEE_LOW);
        }
        if (liquidityMedium > liquidityLow && liquidityMedium >= liquidityHigh) {
            return (poolMedium, FEE_MEDIUM);
        }
        return (poolHigh, FEE_HIGH);
    }

    function getUniSwapCallData(
        address _fromToken,
        address _toToken,
        address _recipient,
        uint256 _amount
    ) public view returns (bytes memory _data) {
        _data = getMulticalSwapData(_fromToken, _toToken, _recipient, _amount);
    }

    function _getSwapCallData(
        address _fromToken,
        address _toToken,
        address _recipient,
        uint256 _amount
    ) public view returns (bytes memory data) {
        bytes memory swapdata = getUniSwapCallData(_fromToken, _toToken, _recipient, _amount);
        data = abi.encodeWithSelector(IBaseSwap.swap.selector, _toToken, _fromToken, _amount, swapdata);
    }
}
