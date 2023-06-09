// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IAaveV2Flashloan {
    function executeOperation(
        address[] memory _assets,
        uint256[] memory _amounts,
        uint256[] memory _premiums,
        address _initiator,
        bytes memory _data
    ) external returns (bool);
}

interface IAaveV3Flashloan {
    function executeOperation(
        address _asset,
        uint256 _amount,
        uint256 _premium,
        address _initiator,
        bytes calldata _data
    ) external returns (bool);
}
