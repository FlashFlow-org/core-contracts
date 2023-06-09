// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { VersionedInitializable } from './dependencies/upgradeability/VersionedInitializable.sol';

import { IRouter } from './interfaces/IRouter.sol';
import { IConnectors } from './interfaces/IConnectors.sol';
import { IACLManager } from './interfaces/IACLManager.sol';
import { IConfigurator } from './interfaces/IConfigurator.sol';
import { IAddressesProvider } from './interfaces/IAddressesProvider.sol';

import { Errors } from './lib/Errors.sol';

/**
 * @title Configurator
 * @author FlashFlow
 * @dev Implements the configuration methods for the FlashFlow protocol
 */
contract Configurator is VersionedInitializable, IConfigurator {
    /* ============ Constants ============ */

    uint256 public constant CONFIGURATOR_REVISION = 0x1;

    /* ============ State Variables ============ */

    IRouter internal _router;
    IConnectors internal _connectors;
    IAddressesProvider internal _addressesProvider;

    /* ============ Events ============ */

    /**
     * @dev Emitted when set new router fee.
     * @param oldFee The old fee, expressed in bps
     * @param newFee The new fee, expressed in bps
     */
    event ChangeRouterFee(uint256 oldFee, uint256 newFee);

    /* ============ Modifiers ============ */

    /**
     * @dev Only pool admin can call functions marked by this modifier.
     */
    modifier onlyRouterAdmin() {
        _onlyRouterAdmin();
        _;
    }

    /**
     * @dev Only connector admin can call functions marked by this modifier.
     */
    modifier onlyConnectorAdmin() {
        _onlyConnectorAdmin();
        _;
    }

    /* ============ Initializer ============ */

    function initialize(IAddressesProvider provider) public initializer {
        _addressesProvider = provider;
        _router = IRouter(_addressesProvider.getRouter());
        _connectors = IConnectors(_addressesProvider.getConnectors());
    }

    /* ============ External Functions ============ */

    /**
     * @notice Set a new fee to the router contract.
     * @param _fee The new amount
     */
    function setFee(uint256 _fee) external onlyRouterAdmin {
        uint256 currentFee = _router.fee();
        _router.setFee(_fee);
        emit ChangeRouterFee(currentFee, _fee);
    }

    /**
     * @dev Add Connectors to the connectors contract
     * @param _names Array of Connector Names.
     * @param _addresses Array of Connector Address.
     */
    function addConnectors(string[] calldata _names, address[] calldata _addresses) external onlyConnectorAdmin {
        _connectors.addConnectors(_names, _addresses);
    }

    /**
     * @dev Update Connectors on the connectors contract
     * @param _names Array of Connector Names.
     * @param _addresses Array of Connector Address.
     */
    function updateConnectors(string[] calldata _names, address[] calldata _addresses) external onlyConnectorAdmin {
        _connectors.updateConnectors(_names, _addresses);
    }

    /**
     * @dev Remove Connectors on the connectors contract
     * @param _names Array of Connector Names.
     */
    function removeConnectors(string[] calldata _names) external onlyConnectorAdmin {
        _connectors.removeConnectors(_names);
    }

    /* ============ Internal Functions ============ */

    function _onlyRouterAdmin() internal view {
        IACLManager aclManager = IACLManager(_addressesProvider.getACLManager());
        require(aclManager.isRouterAdmin(msg.sender), Errors.CALLER_NOT_ROUTER_ADMIN);
    }

    function _onlyConnectorAdmin() internal view {
        IACLManager aclManager = IACLManager(_addressesProvider.getACLManager());
        require(aclManager.isConnectorAdmin(msg.sender), Errors.CALLER_NOT_CONNECTOR_ADMIN);
    }

    /**
     * @notice Returns the version of the Configurator contract.
     * @return The version is needed to update the proxy.
     */
    function getRevision() internal pure override returns (uint256) {
        return CONFIGURATOR_REVISION;
    }
}
