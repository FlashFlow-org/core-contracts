// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Test } from 'forge-std/Test.sol';
import { ERC20 } from 'contracts/dependencies/openzeppelin/contracts/ERC20.sol';

import { DataTypes } from 'contracts/lib/DataTypes.sol';

import { EthConverter } from 'contracts/mocks/EthConverter.sol';

import { VenusConnector } from 'contracts/connectors/bsc/Venus.sol';
import { CTokenInterface } from 'contracts/interfaces/external/compound-v2/CTokenInterfaces.sol';
import { ComptrollerInterface } from 'contracts/interfaces/external/compound-v2/ComptrollerInterface.sol';

import { Tokens } from '../../utils/tokens.sol';

contract LendingHelper is Tokens {
    VenusConnector venusConnector;

    ComptrollerInterface internal constant troller = ComptrollerInterface(0xfD36E2c2a6789Db23113685031d7F16329158384);

    function setUp() public {
        string memory url = vm.rpcUrl('bsc');
        uint256 forkId = vm.createFork(url);
        vm.selectFork(forkId);

        venusConnector = new VenusConnector();
    }

    function getCollateralAmt(address _token, address _recipient) public returns (uint256 collateralAmount) {
        collateralAmount = venusConnector.collateralBalanceOf(_token, _recipient);
    }

    function getBorrowAmt(address _token, address _recipient) public returns (uint256 borrowAmount) {
        borrowAmount = venusConnector.borrowBalanceOf(_token, _recipient);
    }

    function getPaybackData(uint256 _amount, address _token) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(venusConnector.payback.selector, _token, _amount);
    }

    function getWithdrawData(uint256 _amount, address _token) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(venusConnector.withdraw.selector, _token, _amount);
    }

    function getDepositData(address _token, uint256 _amount) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(venusConnector.deposit.selector, _token, _amount);
    }

    function getBorrowData(address _token, uint256 _amount) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(venusConnector.borrow.selector, _token, _amount);
    }

    function execute(bytes memory _data) public {
        (bool success, ) = address(venusConnector).delegatecall(_data);
        require(success);
    }
}

contract VenusLogic is LendingHelper, EthConverter {
    function test_Deposit() public {
        uint256 depositAmount = 1000 ether;

        vm.prank(getToken('dai'));
        ERC20(getToken('dai')).transfer(address(this), depositAmount);

        execute(getDepositData(getToken('dai'), depositAmount));

        assertGt(getCollateralAmt(getToken('dai'), address(this)), 0);
    }

    function test_Deposit_Entered() public {
        uint256 depositAmount = 1000 ether;

        vm.prank(getToken('dai'));
        ERC20(getToken('dai')).transfer(address(this), depositAmount);

        address[] memory toEnter = new address[](1);
        toEnter[0] = address(venusConnector._getCToken(getToken('dai')));
        troller.enterMarkets(toEnter);

        execute(getDepositData(getToken('dai'), depositAmount));

        assertGt(getCollateralAmt(getToken('dai'), address(this)), 0);
    }

    function test_Deposit_Max() public {
        uint256 depositAmount = 1000 ether;

        vm.prank(getToken('dai'));
        ERC20(getToken('dai')).transfer(address(this), depositAmount);

        execute(getDepositData(getToken('dai'), type(uint256).max));

        assertGt(getCollateralAmt(getToken('dai'), address(this)), 0);
    }

    function test_Deposit_InvalidToken() public {
        uint256 depositAmount = 1000 ether;

        vm.prank(getToken('dai'));
        ERC20(getToken('dai')).transfer(address(this), depositAmount);

        vm.expectRevert(abi.encodePacked('Unsupported token'));
        execute(getDepositData(address(msg.sender), depositAmount));
    }

    function test_borrow() public {
        uint256 depositAmount = 1000 ether;

        vm.prank(getToken('dai'));
        ERC20(getToken('dai')).transfer(address(this), depositAmount);

        execute(getDepositData(getToken('dai'), depositAmount));

        uint256 borrowAmount = 100000000;
        execute(getBorrowData(getToken('usdc'), borrowAmount));

        assertEq(borrowAmount, getBorrowAmt(getToken('usdc'), address(this)));
    }

    function test_Payback() public {
        uint256 depositAmount = 1000 ether;

        vm.prank(getToken('dai'));
        ERC20(getToken('dai')).transfer(address(this), depositAmount);

        execute(getDepositData(getToken('dai'), depositAmount));

        uint256 borrowAmount = 100000000;
        execute(getBorrowData(getToken('usdc'), borrowAmount));

        execute(getPaybackData(borrowAmount, getToken('usdc')));

        assertEq(0, getBorrowAmt(getToken('usdc'), address(this)));
    }

    function test_Payback_NotEnoughToken() public {
        uint256 depositAmount = 1000 ether;

        vm.prank(getToken('dai'));
        ERC20(getToken('dai')).transfer(address(this), depositAmount);

        execute(getDepositData(getToken('dai'), depositAmount));

        uint256 borrowAmount = 100000000;
        execute(getBorrowData(getToken('usdc'), borrowAmount));

        vm.expectRevert(abi.encodePacked('not enough token'));
        execute(getPaybackData(borrowAmount + 1000, getToken('usdc')));
    }

    function test_Payback_Max() public {
        uint256 depositAmount = 1000 ether;

        vm.prank(getToken('dai'));
        ERC20(getToken('dai')).transfer(address(this), depositAmount);

        execute(getDepositData(getToken('dai'), depositAmount));

        uint256 borrowAmount = 100000000;
        execute(getBorrowData(getToken('usdc'), borrowAmount));

        execute(getPaybackData(type(uint256).max, getToken('usdc')));

        assertEq(0, getCollateralAmt(getToken('usdc'), address(this)));
    }

    function test_Withdraw() public {
        uint256 depositAmount = 1000 ether;

        vm.prank(getToken('dai'));
        ERC20(getToken('dai')).transfer(address(this), depositAmount);

        execute(getDepositData(getToken('dai'), depositAmount));

        uint256 borrowAmount = 100000000;
        execute(getBorrowData(getToken('usdc'), borrowAmount));

        execute(getPaybackData(borrowAmount, getToken('usdc')));
        execute(getWithdrawData(depositAmount, getToken('dai')));

        assertEq(0, getCollateralAmt(getToken('dai'), address(this)));
    }

    function test_Withdraw_Max() public {
        uint256 depositAmount = 1000 ether;

        vm.prank(getToken('dai'));
        ERC20(getToken('dai')).transfer(address(this), depositAmount);

        execute(getDepositData(getToken('dai'), depositAmount));

        uint256 borrowAmount = 100000000;
        execute(getBorrowData(getToken('usdc'), borrowAmount));

        execute(getPaybackData(borrowAmount, getToken('usdc')));
        execute(getWithdrawData(type(uint256).max, getToken('dai')));

        assertEq(0, getCollateralAmt(getToken('dai'), address(this)));
    }
}
