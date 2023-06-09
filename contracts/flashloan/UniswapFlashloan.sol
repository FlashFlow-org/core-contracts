// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { PoolAddress } from '../dependencies/uniswap/libraries/PoolAddress.sol';
import { CallbackValidation } from '../dependencies/uniswap/libraries/CallbackValidation.sol';

import { PeripheryPayments } from '../dependencies/uniswap/PeripheryPayments.sol';
import { PeripheryImmutableState } from '../dependencies/uniswap/PeripheryImmutableState.sol';

import { IFlashReceiver } from '../interfaces/IFlashReceiver.sol';
import { IUniswapFlashloan } from '../interfaces/connectors/IUniswapFlashloan.sol';

import { IUniswapV3Pool } from '../interfaces/external/uniswap-v3/IUniswapV3Pool.sol';
import { IUniswapV3Factory } from '../interfaces/external/uniswap-v3/IUniswapV3Factory.sol';

import { BaseFlashloan } from './BaseFlashloan.sol';

contract UniswapFlashloan is IUniswapFlashloan, PeripheryImmutableState, PeripheryPayments, BaseFlashloan {
    /* ============ Constants ============ */

    /**
     * @dev Connector name
     */
    string public constant override NAME = 'UniswapFlashloan';

    /* ============ Constructor ============ */

    /**
     * @dev Constructor.
     * @param _factory The address of the Balancer lending contract
     * @param _weth9 The address of the Balancer lending contract
     */
    constructor(address _factory, address _weth9) PeripheryImmutableState(_factory, _weth9) {}

    /* ============ External Functions ============ */

    /**
     * @dev Main function for flashloan for all routes. Calls the middle functions according to routes.
     * @notice Main function for flashloan for all routes. Calls the middle functions according to routes.
     *  _token token addresses for flashloan.
     *  @param _amount list of amounts for the corresponding assets.
     * @param _data extra data passed.
     */
    function flashLoan(address, uint256 _amount, bytes calldata _data) external override reentrancy {
        (FlashParams memory params, bytes memory data) = abi.decode(_data, (FlashParams, bytes));
        if (params.amount0 > 0) {
            params.amount0 = _amount;
        }
        if (params.amount1 > 0) {
            params.amount1 = _amount;
        }
        _flashLoan(params, data);
    }

    /**
     * @dev Main function for flashloan for all routes. Calls the middle functions according to routes.
     * @notice Main function for flashloan for all routes. Calls the middle functions according to routes.
     * @param _params token addresses for flashloan.
     * @param _data extra data passed.
     */
    function _flashLoan(FlashParams memory _params, bytes memory _data) internal {
        bytes memory data = abi.encode(msg.sender, _params, _data);
        _dataHash = bytes32(keccak256(data));

        IUniswapV3Pool pool = IUniswapV3Pool(PoolAddress.computeAddress(factory, _params.poolKey));
        pool.flash(address(this), _params.amount0, _params.amount1, data);
    }

    /**
     * @dev Fallback function for cream finance flashloan.
     * @param _fee0 fee for the flashloan.
     * @param _fee1 fee for the flashloan.
     * @param _data extra data passed(includes route info aswell).
     */
    function uniswapV3FlashCallback(
        uint256 _fee0,
        uint256 _fee1,
        bytes calldata _data
    ) external override verifyDataHash(_data) {
        (address sender, FlashParams memory decoded, bytes memory data) = abi.decode(
            _data,
            (address, FlashParams, bytes)
        );
        CallbackValidation.verifyCallback(factory, decoded.poolKey);

        uint256 amount0Owed = decoded.amount0 + _fee0;
        uint256 amount1Owed = decoded.amount1 + _fee1;

        if (amount0Owed > 0) {
            _executeAndPayback(decoded.poolKey.token0, decoded.amount0, sender, _fee0, data);
        }
        if (amount1Owed > 0) {
            _executeAndPayback(decoded.poolKey.token1, decoded.amount1, sender, _fee1, data);
        }
    }

    function _executeAndPayback(
        address _token,
        uint256 _amount,
        address _sender,
        uint256 _fee,
        bytes memory data
    ) private {
        uint256 amountOwed = _amount + _fee;

        safeApprove(_token, amountOwed, address(this));
        safeTransfer(_token, _amount, _sender);
        IFlashReceiver(_sender).executeOperation(_token, _amount, _fee, _sender, NAME, data);
        pay(_token, address(this), msg.sender, amountOwed);
    }

    function calculateFeeBPS() public view override returns (uint256 bps) {}

    function getAvailability(address _token, uint256 _amount) external view override returns (bool) {}
}
