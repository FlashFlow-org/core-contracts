// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Test } from 'forge-std/Test.sol';
import { ERC20 } from 'contracts/dependencies/openzeppelin/contracts/ERC20.sol';
import { Clones } from 'contracts/dependencies/openzeppelin/upgradeability/Clones.sol';

import { IAddressesProvider } from 'contracts/interfaces/IAddressesProvider.sol';

import { Errors } from 'contracts/lib/Errors.sol';

import { ACLManager } from 'contracts/ACLManager.sol';
import { AddressesProvider } from 'contracts/AddressesProvider.sol';

contract ConnectorImpl {
    string public constant name = 'ConnectorImpl';
}

contract TestACLManager is Test {
    ACLManager aclManager;

    address testAddress;

    // Main identifiers
    function test_addRouterAdmin() public {
        aclManager.addRouterAdmin(address(this));
        assertTrue(aclManager.isRouterAdmin(address(this)));
    }

    function test_removeRouterAdmin() public {
        aclManager.removeRouterAdmin(address(this));
        assertTrue(!aclManager.isRouterAdmin(address(this)));
    }

    function test_addConnectorAdmin() public {
        aclManager.addConnectorAdmin(address(this));
        assertTrue(aclManager.isConnectorAdmin(address(this)));
    }

    function test_addConnectorAdmin_WithSetRole() public {
        aclManager.addRouterAdmin(address(this));
        aclManager.setRoleAdmin(bytes32('ROUTER_ADMIN_ROLE'), bytes32('DEFAULT_ADMIN_ROLE'));

        aclManager.addConnectorAdmin(address(this));
        assertTrue(aclManager.isConnectorAdmin(address(this)));
    }

    function test_removeConnectorAdmin() public {
        aclManager.removeConnectorAdmin(address(this));
        assertTrue(!aclManager.isConnectorAdmin(address(this)));
    }

    receive() external payable {}

    function setUp() public {
        AddressesProvider addressesProvider = new AddressesProvider(address(this));
        addressesProvider.setAddress(bytes32('ACL_ADMIN'), address(this));

        aclManager = new ACLManager(IAddressesProvider(address(addressesProvider)));
    }
}
