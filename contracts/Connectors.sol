// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IConnector } from './interfaces/IConnector.sol';
import { IConnectors } from './interfaces/IConnectors.sol';
import { IAddressesProvider } from './interfaces/IAddressesProvider.sol';

import { Errors } from './lib/Errors.sol';

/**
 * @title Connectors
 * @author FlashFlow
 * @notice Contract to manage and store auxiliary contracts to work with the necessary protocols
 */
contract Connectors is IConnectors {
    /* ============ Immutables ============ */

    // The contract by which all other contact addresses are obtained.
    IAddressesProvider public immutable ADDRESSES_PROVIDER;

    /* ============ State Variables ============ */

    // Enabled Connectors(Connector name => address).
    mapping(string => address) private connectors;

    /* ============ Events ============ */

    /**
     * @dev Emitted when new connector added.
     * @param name Connector name.
     * @param connector Connector contract address.
     */
    event ConnectorAdded(string name, address indexed connector);

    /**
     * @dev Emitted when the router is updated.
     * @param name Connector name.
     * @param oldConnector Old connector contract address.
     * @param newConnector New connector contract address.
     */
    event ConnectorUpdated(string name, address indexed oldConnector, address indexed newConnector);

    /**
     * @dev Emitted when connecter will be removed.
     * @param name Connector name.
     * @param connector Connector contract address.
     */
    event ConnectorRemoved(string name, address indexed connector);

    /* ============ Modifiers ============ */

    /**
     * @dev Only pool configurator can call functions marked by this modifier.
     */
    modifier onlyConfigurator() {
        require(ADDRESSES_PROVIDER.getConfigurator() == msg.sender, Errors.CALLER_NOT_CONFIGURATOR);
        _;
    }

    /* ============ Constructor ============ */

    /**
     * @dev Constructor.
     * @param provider The address of the AddressesProvider contract
     */
    constructor(address provider) {
        ADDRESSES_PROVIDER = IAddressesProvider(provider);
    }

    /* ============ External Functions ============ */

    /**
     * @dev Add Connectors
     * @param _names Array of Connector Names.
     * @param _connectors Array of Connector Address.
     */
    function addConnectors(
        string[] calldata _names,
        address[] calldata _connectors
    ) external override onlyConfigurator {
        require(_names.length == _connectors.length, Errors.INVALID_CONNECTORS_LENGTH);

        for (uint i = 0; i < _connectors.length; i++) {
            string memory name = _names[i];
            address connector = _connectors[i];

            require(connectors[name] == address(0), Errors.CONNECTOR_ALREADY_EXIST);
            require(connector != address(0), Errors.INVALID_CONNECTOR_ADDRESS);
            IConnector(connector).NAME();
            connectors[name] = connector;

            emit ConnectorAdded(name, connector);
        }
    }

    /**
     * @dev Update Connectors
     * @param _names Array of Connector Names.
     * @param _connectors Array of Connector Address.
     */
    function updateConnectors(
        string[] calldata _names,
        address[] calldata _connectors
    ) external override onlyConfigurator {
        require(_names.length == _connectors.length, Errors.INVALID_CONNECTORS_LENGTH);

        for (uint i = 0; i < _connectors.length; i++) {
            string memory name = _names[i];
            address connector = _connectors[i];
            address oldConnector = connectors[name];

            require(connectors[name] != address(0), Errors.CONNECTOR_DOES_NOT_EXIST);
            require(connector != address(0), Errors.INVALID_CONNECTOR_ADDRESS);
            IConnector(connector).NAME();
            connectors[name] = connector;

            emit ConnectorUpdated(name, oldConnector, connector);
        }
    }

    /**
     * @dev Remove Connectors
     * @param _names Array of Connector Names.
     */
    function removeConnectors(string[] calldata _names) external override onlyConfigurator {
        for (uint i = 0; i < _names.length; i++) {
            string memory name = _names[i];
            address connector = connectors[name];

            require(connector != address(0), Errors.CONNECTOR_DOES_NOT_EXIST);

            emit ConnectorRemoved(name, connector);
            delete connectors[name];
        }
    }

    /**
     * @dev Check if Connector addresses are enabled.
     * @param _name Connector Name.
     */
    function isConnector(string calldata _name) external view returns (bool isOk, address connector) {
        isOk = true;
        connector = connectors[_name];

        if (connector == address(0)) {
            isOk = false;
        }
    }
}
