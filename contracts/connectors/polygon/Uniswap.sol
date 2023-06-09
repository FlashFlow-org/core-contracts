// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC20 } from '../../dependencies/openzeppelin/contracts/IERC20.sol';

import { IBaseSwap } from '../../interfaces/IBaseSwap.sol';

import { UniversalERC20 } from '../../lib/UniversalERC20.sol';

contract UniswapConnector is IBaseSwap {
    using UniversalERC20 for IERC20;

    /* ============ Constants ============ */

    /**
     * @dev Connector name
     */
    string public constant NAME = 'UniswapAuto';

    /**
     * @dev UniswapV3 Auto Swap Router Address
     */
    address internal constant UNI_AUTO_ROUTER = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

    /* ============ Events ============ */

    /**
     * @dev Emitted when the sender swap tokens.
     * @param account Address who create operation.
     * @param fromToken The address of the token to sell.
     * @param toToken The address of the token to buy.
     * @param amount The amount of the token to sell.
     */
    event LogExchange(address indexed account, address toToken, address fromToken, uint256 amount);

    /* ============ External Functions ============ */

    /**
     * @dev Sell ETH/ERC20_Token using uniswap v3 auto router.
     * @notice Swap tokens from getting an optimized trade routes
     * @param _toToken The address of the token to buy.
     * @param _fromToken The address of the token to sell.
     * @param _amount The amount of the token to sell.
     * @param _callData Data from uniswap API.
     * @return buyAmount Returns the amount of tokens received.
     */
    function swap(
        address _toToken,
        address _fromToken,
        uint256 _amount,
        bytes calldata _callData
    ) external payable returns (uint256 buyAmount) {
        buyAmount = _swap(_toToken, _fromToken, _amount, _callData);
        emit LogExchange(msg.sender, _toToken, _fromToken, _amount);
    }

    /* ============ Internal Functions ============ */

    /**
     * @dev Universal approve tokens to uniswap router and execute calldata.
     * @param _toToken The address of the token to buy.
     * @param _fromToken The address of the token to sell.
     * @param _amount The amount of the token to sell.
     * @param _callData Data from uniswap API.
     * @return buyAmount Returns the amount of tokens received.
     */
    function _swap(
        address _toToken,
        address _fromToken,
        uint256 _amount,
        bytes calldata _callData
    ) internal returns (uint256 buyAmount) {
        IERC20(_fromToken).universalApprove(UNI_AUTO_ROUTER, _amount);

        uint256 initalBalalance = IERC20(_toToken).universalBalanceOf(address(this));

        (bool success, bytes memory results) = UNI_AUTO_ROUTER.call(_callData);

        if (!success) {
            revert(string(results));
        }

        uint256 finalBalalance = IERC20(_toToken).universalBalanceOf(address(this));

        buyAmount = finalBalalance - initalBalalance;
    }
}
