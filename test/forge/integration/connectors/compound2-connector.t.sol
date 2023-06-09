// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Test } from 'forge-std/Test.sol';
import { ERC20 } from 'contracts/dependencies/openzeppelin/contracts/ERC20.sol';

import { DataTypes } from 'contracts/lib/DataTypes.sol';

import { EthConverter } from 'contracts/mocks/EthConverter.sol';

import { CompoundV2Connector } from 'contracts/connectors/mainnet/CompoundV2.sol';
import { CTokenInterface } from 'contracts/interfaces/external/compound-v2/CTokenInterfaces.sol';
import { ComptrollerInterface } from 'contracts/interfaces/external/compound-v2/ComptrollerInterface.sol';

import { Tokens } from '../../utils/tokens.sol';

interface AaveOracle {
    function getAssetPrice(address asset) external view returns (uint256);
}

contract LendingHelper is Tokens {
    CompoundV2Connector compoundV2Connector;

    ComptrollerInterface internal constant troller = ComptrollerInterface(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);

    function setUp() public {
        string memory url = vm.rpcUrl('mainnet');
        uint256 forkId = vm.createFork(url);
        vm.selectFork(forkId);

        compoundV2Connector = new CompoundV2Connector();
    }

    function getCollateralAmt(address _token, address _recipient) public returns (uint256 collateralAmount) {
        collateralAmount = compoundV2Connector.collateralBalanceOf(_token, _recipient);
    }

    function getBorrowAmt(address _token, address _recipient) public returns (uint256 borrowAmount) {
        borrowAmount = compoundV2Connector.borrowBalanceOf(_token, _recipient);
    }

    function getPaybackData(uint256 _amount, address _token) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(compoundV2Connector.payback.selector, _token, _amount);
    }

    function getWithdrawData(uint256 _amount, address _token) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(compoundV2Connector.withdraw.selector, _token, _amount);
    }

    function getDepositData(address _token, uint256 _amount) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(compoundV2Connector.deposit.selector, _token, _amount);
    }

    function getBorrowData(address _token, uint256 _amount) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(compoundV2Connector.borrow.selector, _token, _amount);
    }

    function execute(bytes memory _data) public {
        (bool success, ) = address(compoundV2Connector).delegatecall(_data);
        require(success);
    }
}

contract CompoundV2Logic is LendingHelper, EthConverter {
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
        toEnter[0] = address(compoundV2Connector._getCToken(getToken('dai')));
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

    function test_GetCToken() public {
        address[] memory _tokens = new address[](19);
        _tokens[0] = address(0);
        _tokens[1] = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;
        _tokens[2] = 0x0D8775F648430679A709E98d2b0Cb6250d2887EF;
        _tokens[3] = 0xc00e94Cb662C3520282E6f5717214004A7f26888;
        _tokens[4] = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        _tokens[5] = 0x956F47F50A910163D8BF957Cf5846D573E7f87CA;
        _tokens[6] = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
        _tokens[7] = 0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2;
        _tokens[8] = 0x1985365e9f78359a9B6AD760e32412f4a445E862;
        _tokens[9] = 0x89d24A6b4CcB1B6fAA2625fE562bDD9a23260359;
        _tokens[10] = 0x6B3595068778DD592e39A122f4f5a5cF09C90fE2;
        _tokens[11] = 0x0000000000085d4780B73119b644AE5ecd22b376;
        _tokens[12] = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
        _tokens[13] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        _tokens[14] = 0x8E870D67F660D95d5be530380D0eC0bd388289E1;
        _tokens[15] = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
        _tokens[16] = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
        _tokens[17] = 0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e;
        _tokens[18] = 0xE41d2489571d322189246DaFA5ebDe1F4699F498;

        for (uint i = 0; i < _tokens.length; i++) {
            CTokenInterface token = compoundV2Connector._getCToken(_tokens[i]);

            // for eth
            if (_tokens[i] != address(0)) {
                assertEq(token.underlying(), _tokens[i]);
            }
        }
    }
}
