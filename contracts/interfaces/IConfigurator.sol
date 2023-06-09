// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IConfigurator {
    function setFee(uint256 _fee) external;

    function addConnectors(string[] calldata _names, address[] calldata _addresses) external;

    function updateConnectors(string[] calldata _names, address[] calldata _addresses) external;

    function removeConnectors(string[] calldata _names) external;
}
