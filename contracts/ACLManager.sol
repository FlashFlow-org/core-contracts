// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { AccessControl } from './dependencies/openzeppelin/contracts/AccessControl.sol';

import { IACLManager } from './interfaces/IACLManager.sol';
import { IAddressesProvider } from './interfaces/IAddressesProvider.sol';

import { Errors } from './lib/Errors.sol';

/**
 * @title ACLManager
 * @author FlashFlow
 * @notice Access Control List Manager. Main registry of system roles and permissions.
 */
contract ACLManager is AccessControl, IACLManager {
    /* ============ Constants ============ */

    bytes32 public constant ROUTER_ADMIN_ROLE = keccak256('ROUTER_ADMIN_ROLE');
    bytes32 public constant CONNECTOR_ADMIN_ROLE = keccak256('CONNECTOR_ADMIN_ROLE');

    /* ============ Immutables ============ */

    IAddressesProvider public immutable ADDRESSES_PROVIDER;

    /* ============ Constructor ============ */

    /**
     * @dev Constructor
     * @dev The ACL admin should be initialized at the addressesProvider beforehand
     * @param provider The address of the AddressesProvider
     */
    constructor(IAddressesProvider provider) {
        ADDRESSES_PROVIDER = provider;
        address aclAdmin = provider.getACLAdmin();
        require(aclAdmin != address(0), Errors.ACL_ADMIN_CANNOT_BE_ZERO);
        _setupRole(DEFAULT_ADMIN_ROLE, aclAdmin);
    }

    /* ============ External Functions ============ */

    function setRoleAdmin(bytes32 role, bytes32 adminRole) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _setRoleAdmin(role, adminRole);
    }

    function addConnectorAdmin(address admin) external override {
        grantRole(CONNECTOR_ADMIN_ROLE, admin);
    }

    function removeConnectorAdmin(address admin) external override {
        revokeRole(CONNECTOR_ADMIN_ROLE, admin);
    }

    function addRouterAdmin(address admin) external override {
        grantRole(ROUTER_ADMIN_ROLE, admin);
    }

    function removeRouterAdmin(address admin) external override {
        revokeRole(ROUTER_ADMIN_ROLE, admin);
    }

    function isConnectorAdmin(address admin) external view override returns (bool) {
        return hasRole(CONNECTOR_ADMIN_ROLE, admin);
    }

    function isRouterAdmin(address admin) external view override returns (bool) {
        return hasRole(ROUTER_ADMIN_ROLE, admin);
    }
}
