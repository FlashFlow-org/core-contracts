// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC20 } from '../dependencies/openzeppelin/contracts/IERC20.sol';

import { IBaseSwap } from '../interfaces/IBaseSwap.sol';
import { IAugustusSwapper } from '../interfaces/external/paraswap/IAugustusSwapper.sol';

import { UniversalERC20 } from '../lib/UniversalERC20.sol';

contract ParaSwapConnector is IBaseSwap {
    using UniversalERC20 for IERC20;

    /* ============ Constants ============ */

    /**
     * @dev Connector name
     */
    string public constant NAME = 'ParaSwap';

    /**
     * @dev Paraswap Router Address
     */
    address internal constant PARASWAP_ROUTER = 0xDEF171Fe48CF0115B1d80b88dc8eAB59176FEe57;

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
     * @dev Swap ETH/ERC20_Token using ParaSwap.
     * @notice Swap tokens from exchanges like kyber, 0x etc, with calculation done off-chain.
     * @param _toToken The address of the token to buy.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _fromToken The address of the token to sell.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _amount The amount of the token to sell.
     * @param _callData Data from ParaSwap API.
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
     * @dev Universal approve tokens to paraswap router and execute calldata.
     * @param _toToken The address of the token to buy.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _fromToken The address of the token to sell.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _amount The amount of the token to sell.
     * @param _callData Data from ParaSwap API.
     * @return buyAmount Returns the amount of tokens received.
     */
    function _swap(
        address _toToken,
        address _fromToken,
        uint256 _amount,
        bytes calldata _callData
    ) internal returns (uint256 buyAmount) {
        address tokenProxy = IAugustusSwapper(PARASWAP_ROUTER).getTokenTransferProxy();
        IERC20(_fromToken).universalApprove(tokenProxy, _amount);

        uint256 value = IERC20(_fromToken).isETH() ? _amount : 0; // matic have the same address

        uint256 initalBalalance = IERC20(_toToken).universalBalanceOf(address(this));

        (bool success, bytes memory results) = PARASWAP_ROUTER.call{ value: value }(_callData);

        if (!success) {
            revert(string(results));
        }

        uint256 finalBalalance = IERC20(_toToken).universalBalanceOf(address(this));

        buyAmount = finalBalalance - initalBalalance;
    }
}
