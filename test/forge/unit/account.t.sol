// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Test } from 'forge-std/Test.sol';
import { ERC20 } from 'contracts/dependencies/openzeppelin/contracts/ERC20.sol';
import { Clones } from 'contracts/dependencies/openzeppelin/upgradeability/Clones.sol';

import { AddressesProvider } from 'contracts/AddressesProvider.sol';
import { IAddressesProvider } from 'contracts/interfaces/IAddressesProvider.sol';

import { Errors } from 'contracts/lib/Errors.sol';
import { ERC20Mock } from 'contracts/mocks/ERC20Mock.sol';

import { Account } from 'contracts/Account.sol';

contract TestAccount is Test {
    Account account;
    ERC20Mock tokenMock;

    mapping(uint => address) public test2;

    // Main identifiers
    function test_claimERC20Token() public {
        uint256 amount = 1000 ether;
        tokenMock.mint(address(account), amount);

        uint256 balanceBefore = tokenMock.balanceOf(msg.sender);

        vm.prank(msg.sender);
        account.claimTokens(address(tokenMock), amount);

        uint256 balanceAfter = tokenMock.balanceOf(msg.sender);

        assertEq(amount, balanceAfter - balanceBefore);
    }

    function test_claimERC20Token_Max() public {
        uint256 amount = 1000 ether;
        tokenMock.mint(address(account), amount);

        uint256 balanceBefore = tokenMock.balanceOf(msg.sender);

        vm.prank(msg.sender);
        account.claimTokens(address(tokenMock), 0);

        uint256 balanceAfter = tokenMock.balanceOf(msg.sender);

        assertEq(amount, balanceAfter - balanceBefore);
    }

    function test_claimEther() public {
        uint256 amount = 1 ether;

        payable(address(account)).transfer(amount);

        uint256 balanceBefore = address(msg.sender).balance;

        vm.prank(msg.sender);
        account.claimTokens(address(0), amount);

        uint256 balanceAfter = address(msg.sender).balance;

        assertEq(amount, balanceAfter - balanceBefore);
    }

    function test_claimEther_Max() public {
        uint256 amount = 1 ether;

        payable(address(account)).transfer(amount);

        uint256 balanceBefore = address(msg.sender).balance;

        vm.prank(msg.sender);
        account.claimTokens(address(0), 0);

        uint256 balanceAfter = address(msg.sender).balance;

        assertEq(amount, balanceAfter - balanceBefore);
    }

    function test_executeOperation_Revert() public {
        bytes[] memory _bytes = new bytes[](1);
        _bytes[0] = bytes('');

        string[] memory _strings = new string[](1);
        _strings[0] = string('');

        vm.expectRevert(bytes(Errors.ADDRESS_IS_ZERO));

        vm.prank(msg.sender);
        account.executeOperation(
            address(0),
            uint256(1 ether),
            uint256(1 ether),
            address(account),
            'AaveV2Flashloan',
            abi.encode(bytes4(''), _strings, _bytes, _bytes)
        );
    }

    receive() external payable {}

    function setUp() public {
        tokenMock = new ERC20Mock('Mock', 'MCK', msg.sender, 1000000 ether);

        address addressesProvider = address(new AddressesProvider(address(this)));

        // need for execute operation revert test
        AddressesProvider(addressesProvider).setAddress(bytes32('FLASHLOAN_AGGREGATOR'), msg.sender);

        account = new Account(addressesProvider);
        account.initialize(msg.sender, IAddressesProvider(addressesProvider));
    }
}
