// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { CErc20Interface } from '../external/compound-v2/CTokenInterfaces.sol';

interface ICompoundV2Connector {
    function NAME() external returns (string memory);

    function deposit(address _token, uint256 _amount) external payable;

    function withdraw(address _token, uint256 _amount) external payable;

    function borrow(address _token, uint256 _amount) external payable;

    function payback(address _token, uint256 _amount) external payable;

    function borrowBalanceOf(address _token, address _recipient) external returns (uint256);

    function collateralBalanceOf(address _token, address _recipient) external returns (uint256);

    function _getCToken(address _token) external pure returns (CErc20Interface);
}
