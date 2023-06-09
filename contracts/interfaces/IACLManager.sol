// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IACLManager {
    function setRoleAdmin(bytes32 _role, bytes32 _adminRole) external;

    function addConnectorAdmin(address _admin) external;

    function removeConnectorAdmin(address _admin) external;

    function addRouterAdmin(address _admin) external;

    function removeRouterAdmin(address _admin) external;

    function isConnectorAdmin(address _admin) external view returns (bool);

    function isRouterAdmin(address _admin) external view returns (bool);
}
