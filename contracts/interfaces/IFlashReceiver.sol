// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IFlashReceiver {
    function executeOperation(
        address _token,
        uint256 _amount,
        uint256 _fee,
        address _initiator,
        string memory _targetName,
        bytes calldata _params
    ) external;
}
