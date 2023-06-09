// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import 'forge-std/Test.sol';
import { ERC20 } from 'contracts/dependencies/openzeppelin/contracts/ERC20.sol';

import { EthConverter } from 'contracts/mocks/EthConverter.sol';
import { AaveV3Connector } from 'contracts/connectors/mainnet/AaveV3.sol';

import { DataTypes } from 'contracts/lib/DataTypes.sol';

import { IPool } from 'contracts/interfaces/external/aave-v3/IPool.sol';
import { IPoolDataProvider } from 'contracts/interfaces/external/aave-v3/IPoolDataProvider.sol';
import { IPoolAddressesProvider } from 'contracts/interfaces/external/aave-v3/IPoolAddressesProvider.sol';

import { Tokens } from '../../utils/tokens.sol';

interface AaveOracle {
    function getAssetPrice(address asset) external view returns (uint256);
}

contract LendingHelper is Tokens {
    uint256 RATE_TYPE = 2;
    string NAME = 'AaveV3';

    AaveV3Connector aaveV3Connector;

    IPoolAddressesProvider internal constant aaveProvider =
        IPoolAddressesProvider(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e);
    IPoolDataProvider internal constant aaveDataProvider =
        IPoolDataProvider(0x7B4EB56E7CD4b454BA8ff71E4518426369a138a3);

    function setUp() public {
        string memory url = vm.rpcUrl('mainnet');
        uint256 forkId = vm.createFork(url);
        vm.selectFork(forkId);

        aaveV3Connector = new AaveV3Connector();
    }

    function getPaybackData(uint256 _amount, address _token) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(aaveV3Connector.payback.selector, _token, _amount, RATE_TYPE);
    }

    function getWithdrawData(uint256 _amount, address _token) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(aaveV3Connector.withdraw.selector, _token, _amount);
    }

    function getDepositData(address _token, uint256 _amount) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(aaveV3Connector.deposit.selector, _token, _amount);
    }

    function getBorrowData(address _token, uint256 _amount) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(aaveV3Connector.borrow.selector, _token, RATE_TYPE, _amount);
    }

    function execute(bytes memory _data) public {
        (bool success, ) = address(aaveV3Connector).delegatecall(_data);
        require(success);
    }
}

contract AaveV3Logic is LendingHelper, EthConverter {
    uint256 public SECONDS_OF_THE_YEAR = 365 days;
    uint256 public RAY = 1e27;

    function test_Deposit() public {
        uint256 depositAmount = 1000 ether;

        vm.prank(getToken('dai'));
        ERC20(getToken('dai')).transfer(address(this), depositAmount);

        execute(getDepositData(getToken('dai'), depositAmount));

        assertEq(depositAmount, aaveV3Connector.getCollateralBalance(getToken('dai'), address(this)));
    }

    function test_Deposit_ReserveAsCollateral() public {
        uint256 depositAmount = 1000 ether;
        vm.prank(getToken('dai'));
        ERC20(getToken('dai')).transfer(address(this), depositAmount);

        execute(getDepositData(getToken('dai'), depositAmount));

        IPool aave = IPool(aaveProvider.getPool());
        aave.setUserUseReserveAsCollateral(getToken('dai'), false);

        vm.prank(getToken('dai'));
        ERC20(getToken('dai')).transfer(address(this), depositAmount);

        execute(getDepositData(getToken('dai'), depositAmount));

        assertTrue(aaveV3Connector.getCollateralBalance(getToken('dai'), address(this)) > 0);
    }

    function test_Deposit_Max() public {
        uint256 depositAmount = 1000 ether;

        vm.prank(getToken('dai'));
        ERC20(getToken('dai')).transfer(address(this), depositAmount);

        execute(getDepositData(getToken('dai'), type(uint256).max));

        assertEq(depositAmount, aaveV3Connector.getCollateralBalance(getToken('dai'), address(this)));
    }

    function test_borrow() public {
        uint256 depositAmount = 1000 ether;

        vm.prank(getToken('dai'));
        ERC20(getToken('dai')).transfer(address(this), depositAmount);

        execute(getDepositData(getToken('dai'), depositAmount));

        uint256 borrowAmount = 0.1 ether;
        execute(getBorrowData(getToken('weth'), borrowAmount));

        assertEq(borrowAmount, aaveV3Connector.getPaybackBalance(getToken('weth'), address(this), RATE_TYPE));
    }

    function test_Payback() public {
        uint256 depositAmount = 1000 ether;

        vm.prank(getToken('dai'));
        ERC20(getToken('dai')).transfer(address(this), depositAmount);

        execute(getDepositData(getToken('dai'), depositAmount));

        uint256 borrowAmount = 0.1 ether;
        execute(getBorrowData(getToken('weth'), borrowAmount));

        execute(getPaybackData(borrowAmount, getToken('weth')));

        assertEq(0, aaveV3Connector.getPaybackBalance(getToken('weth'), address(this), RATE_TYPE));
    }

    function test_Payback_Max() public {
        uint256 depositAmount = 1000 ether;

        vm.prank(getToken('dai'));
        ERC20(getToken('dai')).transfer(address(this), depositAmount);

        execute(getDepositData(getToken('dai'), depositAmount));

        uint256 borrowAmount = 0.1 ether;
        execute(getBorrowData(getToken('weth'), borrowAmount));

        execute(getPaybackData(type(uint256).max, getToken('weth')));

        assertEq(0, aaveV3Connector.getPaybackBalance(getToken('weth'), address(this), RATE_TYPE));
    }

    function test_Withdraw() public {
        uint256 depositAmount = 1000 ether;

        vm.prank(getToken('dai'));
        ERC20(getToken('dai')).transfer(address(this), depositAmount);

        execute(getDepositData(getToken('dai'), depositAmount));

        uint256 borrowAmount = 0.1 ether;
        execute(getBorrowData(getToken('weth'), borrowAmount));

        execute(getPaybackData(borrowAmount, getToken('weth')));
        execute(getWithdrawData(depositAmount, getToken('dai')));

        assertEq(0, aaveV3Connector.getCollateralBalance(getToken('dai'), address(this)));
    }
}
