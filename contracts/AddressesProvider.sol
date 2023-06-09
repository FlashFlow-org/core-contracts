// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Ownable } from './dependencies/openzeppelin//contracts/Ownable.sol';
import { InitializableAdminUpgradeabilityProxy } from './dependencies/openzeppelin/upgradeability/InitializableAdminUpgradeabilityProxy.sol';

import { IAddressesProvider } from './interfaces/IAddressesProvider.sol';

/**
 * @title AddressesProvider
 * @author FlashFlow
 * @notice Main registry of addresses part of or connected to the protocol
 * @dev Acts as factory of proxies, so with right to change its implementations
 */
contract AddressesProvider is Ownable, IAddressesProvider {
    /* ============ Constants ============ */

    // Main identifiers
    bytes32 private constant ROUTER = 'ROUTER';
    bytes32 private constant ACCOUNT = 'ACCOUNT';
    bytes32 private constant TREASURY = 'TREASURY';
    bytes32 private constant ACL_ADMIN = 'ACL_ADMIN';
    bytes32 private constant CONNECTORS = 'CONNECTORS';
    bytes32 private constant ACL_MANAGER = 'ACL_MANAGER';
    bytes32 private constant CONFIGURATOR = 'CONFIGURATOR';
    bytes32 private constant ACCOUNT_PROXY = 'ACCOUNT_PROXY';

    /* ============ State Variables ============ */

    // Map of registered addresses (identifier => registeredAddress)
    mapping(bytes32 => address) private _addresses;

    /* ============ Events ============ */

    /**
     * @dev Emitted when a new non-proxied contract address is registered.
     * @param id The identifier of the contract
     * @param oldAddress The address of the old contract
     * @param newAddress The address of the new contract
     */
    event AddressSet(bytes32 indexed id, address indexed oldAddress, address indexed newAddress);

    /**
     * @dev Emitted when a new proxy is created.
     * @param id The identifier of the proxy
     * @param proxyAddress The address of the created proxy contract
     * @param implementationAddress The address of the implementation contract
     */
    event ProxyCreated(bytes32 indexed id, address indexed proxyAddress, address indexed implementationAddress);

    /**
     * @dev Emitted when the router is updated.
     * @param oldAddress The old address of the Router
     * @param newAddress The new address of the Router
     */
    event RouterUpdated(address indexed oldAddress, address indexed newAddress);

    /**
     * @dev Emitted when the router configurator is updated.
     * @param oldAddress The old address of the Router
     * @param newAddress The new address of the Router
     */
    event ConfiguratorUpdated(address indexed oldAddress, address indexed newAddress);

    /* ============ Constructor ============ */

    /**
     * @dev Constructor.
     * @param _newOwner The owner address of this contract.
     */
    constructor(address _newOwner) {
        transferOwnership(_newOwner);
    }

    /* ============ External Functions ============ */

    /**
     * @dev Set contract address for the current id.
     * @param _id Contract name in bytes32.
     * @param _newAddress New contract address.
     */
    function setAddress(bytes32 _id, address _newAddress) external override onlyOwner {
        address oldAddress = _addresses[_id];
        _addresses[_id] = _newAddress;
        emit AddressSet(_id, oldAddress, _newAddress);
    }

    /**
     * @notice Updates the implementation of the Router, or creates a proxy
     * setting the new `Router` implementation when the function is called for the first time.
     * @param _newRouterImpl The new Router implementation
     */
    function setRouterImpl(address _newRouterImpl) external override onlyOwner {
        address oldRouterImpl = _getProxyImplementation(ROUTER);
        _updateImpl(ROUTER, _newRouterImpl);
        emit RouterUpdated(oldRouterImpl, _newRouterImpl);
    }

    /**
     * @notice Updates the implementation of the Configurator, or creates a proxy
     * setting the new `Configurator` implementation when the function is called for the first time.
     * @param _newConfiguratorImpl The new Configurator implementation
     */
    function setConfiguratorImpl(address _newConfiguratorImpl) external override onlyOwner {
        address oldConfiguratorImpl = _getProxyImplementation(CONFIGURATOR);
        _updateImpl(CONFIGURATOR, _newConfiguratorImpl);
        emit ConfiguratorUpdated(oldConfiguratorImpl, _newConfiguratorImpl);
    }

    /**
     * @notice Returns the address of the Router proxy.
     * @return The Router proxy address
     */
    function getRouter() external view override returns (address) {
        return getAddress(ROUTER);
    }

    /**
     * @notice Returns the address of the Router configurator proxy.
     * @return The Router configurator proxy address
     */
    function getConfigurator() external view override returns (address) {
        return getAddress(CONFIGURATOR);
    }

    /**
     * @notice Returns the address of the ACL admin.
     * @return The address of the ACL admin
     */
    function getACLAdmin() external view override returns (address) {
        return getAddress(ACL_ADMIN);
    }

    /**
     * @notice Returns the address of the ACL manager.
     * @return The address of the ACLManager
     */
    function getACLManager() external view override returns (address) {
        return getAddress(ACL_MANAGER);
    }

    /**
     * @notice Returns the address of the Connectors proxy.
     * @return The Connectors proxy address
     */
    function getConnectors() external view override returns (address) {
        return getAddress(CONNECTORS);
    }

    /**
     * @notice Returns the address of the Treasury proxy.
     * @return The Treasury proxy address
     */
    function getTreasury() external view override returns (address) {
        return getAddress(TREASURY);
    }

    /**
     * @notice Returns the address of the Account implementation.
     * @return The Account implementation address
     */
    function getAccountImpl() external view override returns (address) {
        return getAddress(ACCOUNT);
    }

    /**
     * @notice Returns the address of the Account proxy.
     * @return The Account proxy address
     */
    function getAccountProxy() external view override returns (address) {
        return getAddress(ACCOUNT_PROXY);
    }

    /* ============ Public Functions ============ */

    /**
     * @param _id The key to obtain the address.
     * @return Returns the contract address.
     */
    function getAddress(bytes32 _id) public view override returns (address) {
        return _addresses[_id];
    }

    /* ============ Internal Functions ============ */

    /**
     * @notice Internal function to update the implementation of a specific proxied component of the protocol.
     * @dev If there is no proxy registered with the given identifier, it creates the proxy setting `newAddress`
     *   as implementation and calls the initialize() function on the proxy
     * @dev If there is already a proxy registered, it just updates the implementation to `newAddress` and
     *   calls the initialize() function via upgradeToAndCall() in the proxy
     * @param id The id of the proxy to be updated
     * @param newAddress The address of the new implementation
     */
    function _updateImpl(bytes32 id, address newAddress) internal {
        address proxyAddress = _addresses[id];
        InitializableAdminUpgradeabilityProxy proxy;
        bytes memory params = abi.encodeWithSignature('initialize(address)', address(this));

        if (proxyAddress == address(0)) {
            proxy = new InitializableAdminUpgradeabilityProxy();
            _addresses[id] = proxyAddress = address(proxy);
            proxy.initialize(newAddress, address(this), params);
            emit ProxyCreated(id, proxyAddress, newAddress);
        } else {
            proxy = InitializableAdminUpgradeabilityProxy(payable(proxyAddress));
            proxy.upgradeToAndCall(newAddress, params);
        }
    }

    /**
     * @notice Returns the the implementation contract of the proxy contract by its identifier.
     * @dev It returns ZERO if there is no registered address with the given id
     * @dev It reverts if the registered address with the given id is not `InitializableAdminUpgradeabilityProxy`
     * @param id The id
     * @return The address of the implementation contract
     */
    function _getProxyImplementation(bytes32 id) internal returns (address) {
        address proxyAddress = _addresses[id];
        if (proxyAddress == address(0)) {
            return address(0);
        } else {
            address payable payableProxyAddress = payable(proxyAddress);
            return InitializableAdminUpgradeabilityProxy(payableProxyAddress).implementation();
        }
    }
}
