// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IMakerFlashloan {
    function onFlashLoan(
        address _initiator,
        address,
        uint256,
        uint256,
        bytes calldata _data
    ) external returns (bytes32);
}
