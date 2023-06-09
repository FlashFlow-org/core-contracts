// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IAaveV3Connector {
    function NAME() external returns (string memory);

    function deposit(address _token, uint256 _amount) external payable;

    function withdraw(address _token, uint256 _amount) external payable;

    function borrow(address _token, uint256 _rateMode, uint256 _amount) external payable;

    function payback(address _token, uint256 _amount, uint256 _rateMode) external payable;

    function getPaybackBalance(address _token, address _recipeint, uint256 _rateMode) external view returns (uint256);

    function getCollateralBalance(address _token, address _recipeint) external view returns (uint256 balance);
}
