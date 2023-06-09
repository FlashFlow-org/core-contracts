// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Test } from 'forge-std/Test.sol';
import { IERC20 } from 'contracts/dependencies/openzeppelin/contracts/IERC20.sol';

import { IAddressesProvider } from 'contracts/interfaces/IAddressesProvider.sol';

import { Connectors } from 'contracts/Connectors.sol';
import { ACLManager } from 'contracts/ACLManager.sol';
import { Configurator } from 'contracts/Configurator.sol';
import { AddressesProvider } from 'contracts/AddressesProvider.sol';

import { Errors } from 'contracts/lib/Errors.sol';

contract ConnectorImpl {
    string public constant NAME = 'ConnectorImpl';
}

contract TestConnectors is Test {
    Connectors connectors;
    Configurator configurator;
    ACLManager aclManager;
    AddressesProvider addressesProvider;

    function test_addConnectors_InvalidLength() public {
        ConnectorImpl connector = new ConnectorImpl();

        string[] memory _names = new string[](1);
        _names[0] = connector.NAME();

        address[] memory _connectors = new address[](2);
        _connectors[0] = address(connector);

        vm.expectRevert(abi.encodePacked(Errors.INVALID_CONNECTORS_LENGTH));
        configurator.addConnectors(_names, _connectors);
    }

    function test_addConnectors_InvalidAddress() public {
        ConnectorImpl connector = new ConnectorImpl();

        string[] memory _names = new string[](1);
        _names[0] = connector.NAME();

        address[] memory _connectors = new address[](1);
        _connectors[0] = address(0);

        vm.expectRevert(abi.encodePacked(Errors.INVALID_CONNECTOR_ADDRESS));
        configurator.addConnectors(_names, _connectors);
    }

    function test_addConnectors_AlreadyExist() public {
        ConnectorImpl connector = new ConnectorImpl();

        string[] memory _names = new string[](2);
        _names[0] = connector.NAME();
        _names[1] = connector.NAME(); // same name

        address[] memory _connectors = new address[](2);
        _connectors[0] = address(connector);
        _connectors[1] = address(new ConnectorImpl());

        vm.expectRevert(abi.encodePacked(Errors.CONNECTOR_ALREADY_EXIST));
        configurator.addConnectors(_names, _connectors);
    }

    function test_addConnectors() public {
        ConnectorImpl connector = new ConnectorImpl();

        string[] memory _names = new string[](1);
        _names[0] = connector.NAME();

        address[] memory _connectors = new address[](1);
        _connectors[0] = address(connector);

        configurator.addConnectors(_names, _connectors);

        (bool isOk, address _connector) = connectors.isConnector(_names[0]);
        assertTrue(isOk);
        assertEq(_connectors[0], _connector);
    }

    function test_updateConnectors_InvalidLength() public {
        ConnectorImpl connector = new ConnectorImpl();

        string[] memory _names = new string[](1);
        _names[0] = connector.NAME();

        address[] memory _connectors = new address[](2);
        _connectors[0] = address(connector);

        vm.expectRevert(abi.encodePacked(Errors.INVALID_CONNECTORS_LENGTH));
        configurator.updateConnectors(_names, _connectors);
    }

    function test_updateConnectors_InvalidAddress() public {
        ConnectorImpl connector = new ConnectorImpl();

        string[] memory _names = new string[](1);
        _names[0] = connector.NAME();

        address[] memory _connectors = new address[](1);
        _connectors[0] = address(connector);

        configurator.addConnectors(_names, _connectors);

        _connectors[0] = address(0);

        vm.expectRevert(abi.encodePacked(Errors.INVALID_CONNECTOR_ADDRESS));
        configurator.updateConnectors(_names, _connectors);
    }

    function test_updateConnectors_DoesntExist() public {
        ConnectorImpl connector = new ConnectorImpl();

        string[] memory _names = new string[](2);
        _names[0] = connector.NAME();

        address[] memory _connectors = new address[](2);
        _connectors[0] = address(connector);

        vm.expectRevert(abi.encodePacked(Errors.CONNECTOR_DOES_NOT_EXIST));
        configurator.updateConnectors(_names, _connectors);
    }

    function test_updateConnectors() public {
        ConnectorImpl connector = new ConnectorImpl();

        string[] memory _names = new string[](1);
        _names[0] = connector.NAME();

        address[] memory _connectors = new address[](1);
        _connectors[0] = address(connector);

        configurator.addConnectors(_names, _connectors);

        (bool isOk0, address _connector0) = connectors.isConnector(_names[0]);
        assertTrue(isOk0);
        assertEq(_connectors[0], _connector0);

        address newConnector = address(new ConnectorImpl());
        _connectors[0] = newConnector;

        configurator.updateConnectors(_names, _connectors);

        (bool isOk1, address _connector1) = connectors.isConnector(_names[0]);
        assertTrue(isOk1);
        assertEq(newConnector, _connector1);
    }

    function test_removeConnectors_DoesntExist() public {
        ConnectorImpl connector = new ConnectorImpl();

        string[] memory _names = new string[](2);
        _names[0] = connector.NAME();

        address[] memory _connectors = new address[](2);
        _connectors[0] = address(connector);

        vm.expectRevert(abi.encodePacked(Errors.CONNECTOR_DOES_NOT_EXIST));
        configurator.removeConnectors(_names);
    }

    function test_removeConnectors() public {
        ConnectorImpl connector = new ConnectorImpl();

        string[] memory _names = new string[](1);
        _names[0] = connector.NAME();

        address[] memory _connectors = new address[](1);
        _connectors[0] = address(connector);

        configurator.addConnectors(_names, _connectors);

        (bool isTrue, address _connector) = connectors.isConnector(_names[0]);
        assertTrue(isTrue);
        assertEq(_connectors[0], _connector);

        configurator.removeConnectors(_names);

        (bool isFalse, address _removeConnector) = connectors.isConnector(_names[0]);
        assertFalse(isFalse);
        assertEq(address(0), _removeConnector);
    }

    receive() external payable {}

    function setUp() public {
        addressesProvider = new AddressesProvider(address(this));
        addressesProvider.setAddress(bytes32('ACL_ADMIN'), address(this));

        aclManager = new ACLManager(IAddressesProvider(address(addressesProvider)));
        connectors = new Connectors(address(addressesProvider));

        aclManager.addConnectorAdmin(address(this));

        addressesProvider.setAddress(bytes32('ACL_MANAGER'), address(aclManager));
        addressesProvider.setAddress(bytes32('CONNECTORS'), address(connectors));

        configurator = new Configurator();
        addressesProvider.setConfiguratorImpl(address(configurator));

        configurator = Configurator(addressesProvider.getConfigurator());
    }
}
