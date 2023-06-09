// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IAaveV2Connector {
    function NAME() external returns (string memory);

    function deposit(address _token, uint256 _amount) external payable;

    function withdraw(address _token, uint256 _amount) external payable;

    function borrow(address _token, uint256 _rateMode, uint256 _amount) external payable;

    function payback(address _token, uint256 _amount, uint256 _rateMode) external payable;

    function getPaybackBalance(address _token, uint _rateMode, address _user) external view returns (uint);

    function getCollateralBalance(address _token, address _user) external view returns (uint256 balance);
}
