// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IAddressesProvider {
    function setAddress(bytes32 _id, address _newAddress) external;

    function setRouterImpl(address _newRouterImpl) external;

    function setConfiguratorImpl(address _newConfiguratorImpl) external;

    function getRouter() external view returns (address);

    function getConfigurator() external view returns (address);

    function getACLAdmin() external view returns (address);

    function getACLManager() external view returns (address);

    function getConnectors() external view returns (address);

    function getTreasury() external view returns (address);

    function getAccountImpl() external view returns (address);

    function getAccountProxy() external view returns (address);

    function getAddress(bytes32 _id) external view returns (address);
}
