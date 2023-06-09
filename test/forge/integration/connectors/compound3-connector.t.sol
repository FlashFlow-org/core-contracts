// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Test } from 'forge-std/Test.sol';
import { ERC20 } from 'contracts/dependencies/openzeppelin/contracts/ERC20.sol';

import { DataTypes } from 'contracts/lib/DataTypes.sol';
import { EthConverter } from 'contracts/mocks/EthConverter.sol';

import { CompoundV3Connector } from 'contracts/connectors/CompoundV3.sol';

import { Tokens } from '../../utils/tokens.sol';

contract LendingHelper is Tokens {
    address USDC_MARKET = 0xc3d688B66703497DAA19211EEdff47f25384cdc3;

    CompoundV3Connector compoundV3Connector;

    function setUp() public {
        string memory url = vm.rpcUrl('mainnet');
        uint256 forkId = vm.createFork(url);
        vm.selectFork(forkId);

        compoundV3Connector = new CompoundV3Connector();
    }

    function getCollateralAmt(address _token, address _recipient) public view returns (uint256 collateralAmount) {
        collateralAmount = compoundV3Connector.collateralBalanceOf(USDC_MARKET, _recipient, _token);
    }

    function getBorrowAmt(address _recipient) public view returns (uint256 borrowAmount) {
        borrowAmount = compoundV3Connector.borrowBalanceOf(USDC_MARKET, _recipient);
    }

    function getPaybackData(uint256 _amount, address _token) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(compoundV3Connector.payback.selector, USDC_MARKET, _token, _amount);
    }

    function getWithdrawData(uint256 _amount, address _token) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(compoundV3Connector.withdraw.selector, USDC_MARKET, _token, _amount);
    }

    function getDepositData(address _token, uint256 _amount) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(compoundV3Connector.deposit.selector, USDC_MARKET, _token, _amount);
    }

    function getBorrowData(address _token, uint256 _amount) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(compoundV3Connector.borrow.selector, USDC_MARKET, _token, _amount);
    }

    function execute(bytes memory _data) public {
        (bool success, ) = address(compoundV3Connector).delegatecall(_data);
        require(success);
    }
}

contract CompoundV3Logic is LendingHelper, EthConverter {
    function test_Deposit() public {
        uint256 depositAmount = 1 ether;
        convertEthToWeth(address(0), depositAmount);

        execute(getDepositData(getToken('weth'), depositAmount));
        assertEq(depositAmount, getCollateralAmt(getToken('weth'), address(this)));
    }

    function test_Deposit_MaxAmount() public {
        uint256 depositAmount = 1 ether;
        convertEthToWeth(address(0), depositAmount);

        execute(getDepositData(getToken('weth'), type(uint256).max));
        assertEq(depositAmount, getCollateralAmt(getToken('weth'), address(this)));
    }

    function test_Deposit_InvalidToken() public {
        uint256 depositAmount = 1 ether;
        convertEthToWeth(address(0), depositAmount);

        vm.expectRevert(abi.encodePacked('invalid market/token address'));
        execute(getDepositData(address(0), type(uint256).max));
    }

    function test_Deposit_InvalidMarket() public {
        uint256 depositAmount = 1 ether;
        convertEthToWeth(address(0), depositAmount);

        vm.expectRevert(abi.encodePacked('invalid market/token address'));
        execute(
            abi.encodeWithSelector(compoundV3Connector.deposit.selector, address(0), getToken('weth'), depositAmount)
        );
    }

    function test_Deposit_DebtNotRepaid() public {
        uint256 depositAmount = 1 ether;
        convertEthToWeth(address(0), depositAmount);

        execute(getDepositData(getToken('weth'), depositAmount));

        execute(getBorrowData(getToken('usdc'), 100000000));

        uint256 depositAmount2 = 1000000000;

        deal(getToken('usdc'), address(this), depositAmount2);

        vm.expectRevert(abi.encodePacked('debt not repaid'));
        execute(getDepositData(getToken('usdc'), depositAmount2));
    }

    function test_borrow() public {
        uint256 depositAmount = 1 ether;
        convertEthToWeth(address(0), depositAmount);

        execute(getDepositData(getToken('weth'), depositAmount));

        uint256 borrowAmount = 100000000;
        execute(getBorrowData(getToken('usdc'), borrowAmount));
        assertEq(borrowAmount, getBorrowAmt(address(this)));
    }

    function test_borrow_InvalidMarket() public {
        uint256 depositAmount = 1 ether;
        convertEthToWeth(address(0), depositAmount);

        execute(getDepositData(getToken('weth'), depositAmount));

        uint256 borrowAmount = 100000000;
        vm.expectRevert(abi.encodePacked('invalid market address'));
        execute(
            abi.encodeWithSelector(compoundV3Connector.borrow.selector, address(0), getToken('usdc'), borrowAmount)
        );
    }

    function test_borrow_InvalidToken() public {
        uint256 depositAmount = 1 ether;
        convertEthToWeth(address(0), depositAmount);

        execute(getDepositData(getToken('weth'), depositAmount));

        uint256 borrowAmount = 100000000;
        vm.expectRevert(abi.encodePacked('invalid token'));
        execute(getBorrowData(getToken('weth'), borrowAmount));
    }

    function test_borrow_Disabled() public {
        uint256 depositAmount = 1000000000;

        deal(getToken('usdc'), address(this), depositAmount);

        execute(getDepositData(getToken('usdc'), depositAmount));

        uint256 borrowAmount = 100000000;
        vm.expectRevert(abi.encodePacked('borrow-disabled-when-supplied-base'));
        execute(getBorrowData(getToken('usdc'), borrowAmount));
    }

    function test_payback() public {
        uint256 depositAmount = 1 ether;
        convertEthToWeth(address(0), depositAmount);

        execute(getDepositData(getToken('weth'), depositAmount));

        uint256 borrowAmount = 100000000;
        execute(getBorrowData(getToken('usdc'), borrowAmount));
        execute(getPaybackData(borrowAmount, getToken('usdc')));

        assertEq(0, getBorrowAmt(address(this)));
    }

    function test_payback_InvalidToken() public {
        uint256 depositAmount = 1 ether;
        convertEthToWeth(address(0), depositAmount);

        execute(getDepositData(getToken('weth'), depositAmount));

        uint256 borrowAmount = 100000000;
        execute(getBorrowData(getToken('usdc'), borrowAmount));
        vm.expectRevert(abi.encodePacked('invalid market/token address'));
        execute(getPaybackData(borrowAmount, address(0)));
    }

    function test_payback_InvalidMarket() public {
        uint256 depositAmount = 1 ether;
        convertEthToWeth(address(0), depositAmount);

        execute(getDepositData(getToken('weth'), depositAmount));

        uint256 borrowAmount = 100000000;
        execute(getBorrowData(getToken('usdc'), borrowAmount));
        vm.expectRevert(abi.encodePacked('invalid market/token address'));
        execute(
            abi.encodeWithSelector(compoundV3Connector.payback.selector, address(0), getToken('usdc'), borrowAmount)
        );
    }

    function test_payback_InvalidBaseToken() public {
        uint256 depositAmount = 1 ether;
        convertEthToWeth(address(0), depositAmount);

        execute(getDepositData(getToken('weth'), depositAmount));

        uint256 borrowAmount = 100000000;
        execute(getBorrowData(getToken('usdc'), borrowAmount));
        vm.expectRevert(abi.encodePacked('invalid token'));
        execute(getPaybackData(borrowAmount, getToken('weth')));
    }

    function test_payback_GreaterThanBorrows() public {
        uint256 depositAmount = 1 ether;
        convertEthToWeth(address(0), depositAmount);

        execute(getDepositData(getToken('weth'), depositAmount));

        uint256 borrowAmount = 100000000;
        execute(getBorrowData(getToken('usdc'), borrowAmount));
        vm.expectRevert(abi.encodePacked('payback-amount-greater-than-borrows'));
        execute(getPaybackData(borrowAmount + 100, getToken('usdc')));
    }

    function test_payback_max() public {
        uint256 depositAmount = 1 ether;
        convertEthToWeth(address(0), depositAmount);

        execute(getDepositData(getToken('weth'), depositAmount));

        uint256 borrowAmount = 100000000;
        execute(getBorrowData(getToken('usdc'), borrowAmount));
        execute(getPaybackData(type(uint256).max, getToken('usdc')));

        assertEq(0, getBorrowAmt(address(this)));
    }

    function test_withdraw() public {
        uint256 depositAmount = 1 ether;
        convertEthToWeth(address(0), depositAmount);

        execute(getDepositData(getToken('weth'), depositAmount));

        uint256 borrowAmount = 100000000;
        execute(getBorrowData(getToken('usdc'), borrowAmount));
        execute(getPaybackData(borrowAmount, getToken('usdc')));

        execute(getWithdrawData(depositAmount, getToken('weth')));

        assertEq(0, getCollateralAmt(getToken('weth'), address(this)));
    }

    function test_withdraw_InvalidMarket() public {
        uint256 depositAmount = 1 ether;
        convertEthToWeth(address(0), depositAmount);

        execute(getDepositData(getToken('weth'), depositAmount));

        uint256 borrowAmount = 100000000;
        execute(getBorrowData(getToken('usdc'), borrowAmount));
        execute(getPaybackData(borrowAmount, getToken('usdc')));

        vm.expectRevert(abi.encodePacked('invalid market/token address'));
        execute(
            abi.encodeWithSelector(compoundV3Connector.withdraw.selector, address(0), getToken('weth'), depositAmount)
        );
    }

    function test_withdraw_InvalidToken() public {
        uint256 depositAmount = 1 ether;
        convertEthToWeth(address(0), depositAmount);

        execute(getDepositData(getToken('weth'), depositAmount));

        uint256 borrowAmount = 100000000;
        execute(getBorrowData(getToken('usdc'), borrowAmount));
        execute(getPaybackData(borrowAmount, getToken('usdc')));

        vm.expectRevert(abi.encodePacked('invalid market/token address'));
        execute(getWithdrawData(depositAmount, address(0)));
    }

    function test_withdraw_GreaterThanSupplies() public {
        uint256 depositAmount = 1 ether;
        convertEthToWeth(address(0), depositAmount);

        execute(getDepositData(getToken('weth'), depositAmount));

        uint256 borrowAmount = 100000000;
        execute(getBorrowData(getToken('usdc'), borrowAmount));
        execute(getPaybackData(borrowAmount, getToken('usdc')));

        vm.expectRevert(abi.encodePacked('withdraw-amount-greater-than-supplies'));
        execute(getWithdrawData(10000000000, getToken('usdc')));
    }

    function test_withdraw_Max() public {
        uint256 depositAmount = 1 ether;
        convertEthToWeth(address(0), depositAmount);

        execute(getDepositData(getToken('weth'), depositAmount));

        uint256 borrowAmount = 100000000;
        execute(getBorrowData(getToken('usdc'), borrowAmount));
        execute(getPaybackData(borrowAmount, getToken('usdc')));

        execute(getWithdrawData(type(uint256).max, getToken('weth')));

        assertEq(0, getCollateralAmt(getToken('weth'), address(this)));
    }
}
