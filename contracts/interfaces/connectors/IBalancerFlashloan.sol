// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IBalancerFlashloan {
    function receiveFlashLoan(address[] memory, uint256[] memory, uint256[] memory _fees, bytes memory _data) external;
}
