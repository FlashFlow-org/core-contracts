// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ICompoundV3Connector {
    struct BorrowWithdrawParams {
        address _market;
        address _token;
        address from;
        address to;
        uint256 _amount;
    }

    struct BuyCollateralData {
        address _market;
        address sellToken;
        address buyAsset;
        uint256 unit_amount;
        uint256 baseSell_amount;
    }

    enum Action {
        REPAY,
        DEPOSIT
    }

    function NAME() external returns (string memory);

    function deposit(address _market, address _token, uint256 _amount) external payable;

    function borrowBalanceOf(address _market, address _recipient) external view returns (uint256);

    function collateralBalanceOf(address _market, address _recipient, address _token) external view returns (uint256);

    function withdraw(address _market, address _token, uint256 _amount) external payable;

    function borrow(address _market, address _token, uint256 _amount) external payable;

    function payback(address _market, address _token, uint256 _amount) external payable;
}
