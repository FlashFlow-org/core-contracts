// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IBaseSwap {
    function NAME() external returns (string memory);

    function swap(
        address _toToken,
        address _fromToken,
        uint256 _amount,
        bytes calldata _callData
    ) external payable returns (uint256 buyAmount);
}
