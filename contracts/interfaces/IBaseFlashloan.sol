// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IBaseFlashloan {
    function NAME() external returns (string memory);

    function flashLoan(address _token, uint256 _amount, bytes calldata _data) external;

    function calculateFeeBPS() external view returns (uint256 bps);

    function getAvailability(address _token, uint256 _amount) external view returns (bool);
}
