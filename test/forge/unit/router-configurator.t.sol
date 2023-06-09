// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Test } from 'forge-std/Test.sol';
import { ERC20 } from 'contracts/dependencies/openzeppelin/contracts/ERC20.sol';
import { Clones } from 'contracts/dependencies/openzeppelin/upgradeability/Clones.sol';

import { Errors } from 'contracts/lib/Errors.sol';
import { IAddressesProvider } from 'contracts/interfaces/IAddressesProvider.sol';

import { Router } from 'contracts/Router.sol';
import { Connectors } from 'contracts/Connectors.sol';
import { ACLManager } from 'contracts/ACLManager.sol';
import { Configurator } from 'contracts/Configurator.sol';
import { AddressesProvider } from 'contracts/AddressesProvider.sol';

contract ConnectorImpl {
    string public constant NAME = 'ConnectorImpl';
}

contract TestConfigurator is Test {
    Router router;
    Configurator configurator;
    Connectors connectors;
    ACLManager aclManager;
    AddressesProvider addressesProvider;

    address testAddress;

    // Main identifiers
    function test_setFee() public {
        aclManager.addRouterAdmin(address(this));
        _setFee();
    }

    function test_setFee_NotRouterAdmin() public {
        vm.expectRevert(abi.encodePacked(Errors.CALLER_NOT_ROUTER_ADMIN));
        configurator.setFee(5);
    }

    function test_setFee_NotConnectorAdmin() public {
        ConnectorImpl connector = new ConnectorImpl();

        string[] memory _names = new string[](1);
        _names[0] = connector.NAME();

        address[] memory _connectors = new address[](1);
        _connectors[0] = address(connector);

        vm.expectRevert(abi.encodePacked(Errors.CALLER_NOT_CONNECTOR_ADMIN));
        configurator.addConnectors(_names, _connectors);
    }

    function test_addConnectors() public {
        aclManager.addConnectorAdmin(address(this));
        _addConnectors();
    }

    function test_init() public {
        Configurator configurator2 = new Configurator();
        configurator2.initialize(IAddressesProvider(address(addressesProvider)));
    }

    function _setFee() public {
        assertEq(router.fee(), 50);

        configurator.setFee(5);
        assertEq(router.fee(), 5);
    }

    function _addConnectors() public {
        ConnectorImpl connector = new ConnectorImpl();

        string[] memory _names = new string[](1);
        _names[0] = connector.NAME();

        address[] memory _connectors = new address[](1);
        _connectors[0] = address(connector);

        configurator.addConnectors(_names, _connectors);
    }

    receive() external payable {}

    function setUp() public {
        addressesProvider = new AddressesProvider(address(this));
        addressesProvider.setAddress(bytes32('ACL_ADMIN'), address(this));

        aclManager = new ACLManager(IAddressesProvider(address(addressesProvider)));
        connectors = new Connectors(address(addressesProvider));

        addressesProvider.setAddress(bytes32('ACL_MANAGER'), address(aclManager));
        addressesProvider.setAddress(bytes32('CONNECTORS'), address(connectors));

        configurator = new Configurator();

        router = new Router(IAddressesProvider(address(addressesProvider)));
        addressesProvider.setRouterImpl(address(router));
        addressesProvider.setConfiguratorImpl(address(configurator));

        configurator = Configurator(addressesProvider.getConfigurator());
        router = Router(payable(addressesProvider.getRouter()));
    }
}
