// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { DataTypes } from '../lib/DataTypes.sol';

interface IRouter {
    struct SwapParams {
        address fromToken;
        address toToken;
        uint256 amount;
        string targetName;
        bytes data;
    }

    function fee() external view returns (uint256);

    function positionsIndex(address _account) external view returns (uint256);

    function positions(
        bytes32 _key
    ) external view returns (address, address, address, uint256, uint256, uint256, uint256);

    function accounts(address _owner) external view returns (address);

    function setFee(uint256 _fee) external;

    function swapAndOpen(
        DataTypes.Position memory _position,
        string memory _targetName,
        bytes calldata _data,
        SwapParams memory _params
    ) external payable;

    function openPosition(
        DataTypes.Position memory _position,
        string memory _targetName,
        bytes calldata _data
    ) external;

    function closePosition(
        bytes32 _key,
        address _token,
        uint256 _amount,
        string memory _targetName,
        bytes calldata _data
    ) external;

    function swap(SwapParams memory _params) external payable;

    function updatePosition(DataTypes.Position memory _position) external;

    function getOrCreateAccount(address _owner) external returns (address);

    function getKey(address _account, uint256 _index) external pure returns (bytes32);

    function predictDeterministicAddress(address _owner) external view returns (address predicted);

    function getFeeAmount(uint256 _amount) external view returns (uint256 feeAmount);
}
