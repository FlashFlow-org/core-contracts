// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IConnectors {
    function addConnectors(string[] calldata _names, address[] calldata _connectors) external;

    function updateConnectors(string[] calldata _names, address[] calldata _connectors) external;

    function removeConnectors(string[] calldata _names) external;

    function isConnector(string calldata _name) external view returns (bool isOk, address _connector);
}
