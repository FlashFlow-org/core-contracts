// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { ERC20 } from 'contracts/dependencies/openzeppelin/contracts/ERC20.sol';

import { Connectors } from 'contracts/Connectors.sol';
import { EthConverter } from 'contracts/mocks/EthConverter.sol';
import { AaveV2Connector } from 'contracts/connectors/mainnet/AaveV2.sol';

import { DataTypes } from 'contracts/lib/DataTypes.sol';
import { ILendingPool } from 'contracts/interfaces/external/aave-v2/ILendingPool.sol';
import { IProtocolDataProvider } from 'contracts/interfaces/external/aave-v2/IProtocolDataProvider.sol';
import { ILendingPoolAddressesProvider } from 'contracts/interfaces/external/aave-v2/ILendingPoolAddressesProvider.sol';

import { Tokens } from '../../utils/tokens.sol';

interface AaveOracle {
    function getAssetPrice(address asset) external view returns (uint256);
}

contract LendingHelper is Tokens {
    uint256 RATE_TYPE = 2;
    string NAME = 'AaveV3';

    AaveV2Connector aaveV2Connector;

    ILendingPoolAddressesProvider internal constant aaveProvider =
        ILendingPoolAddressesProvider(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5);
    IProtocolDataProvider internal constant aaveDataProvider =
        IProtocolDataProvider(0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d);

    function setUp() public {
        string memory url = vm.rpcUrl('mainnet');
        uint256 forkId = vm.createFork(url);
        vm.selectFork(forkId);

        aaveV2Connector = new AaveV2Connector();
    }

    function getCollateralAmt(address _token, address _recipient) public view returns (uint256 collateralAmount) {
        collateralAmount = aaveV2Connector.getCollateralBalance(_token, _recipient);
    }

    function getBorrowAmt(address _token, address _recipient) public view returns (uint256 borrowAmount) {
        borrowAmount = aaveV2Connector.getPaybackBalance(_token, RATE_TYPE, _recipient);
    }

    function getPaybackData(uint256 _amount, address _token) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(aaveV2Connector.payback.selector, _token, _amount, RATE_TYPE);
    }

    function getWithdrawData(uint256 _amount, address _token) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(aaveV2Connector.withdraw.selector, _token, _amount);
    }

    function getDepositData(address _token, uint256 _amount) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(aaveV2Connector.deposit.selector, _token, _amount);
    }

    function getBorrowData(address _token, uint256 _amount, uint256 _rate) public view returns (bytes memory _data) {
        _data = abi.encodeWithSelector(aaveV2Connector.borrow.selector, _token, _rate, _amount);
    }

    function execute(bytes memory _data) public {
        (bool success, ) = address(aaveV2Connector).delegatecall(_data);
        require(success);
    }
}

contract AaveV2 is LendingHelper, EthConverter {
    uint256 public RAY = 1e27;
    uint256 public SECONDS_OF_THE_YEAR = 365 days;

    function test_Deposit() public {
        uint256 depositAmount = 1000 ether;
        depositDai(depositAmount);
        assertGt(getCollateralAmt(getToken('dai'), address(this)), 0);
    }

    function test_Deposit_ReserveAsCollateral() public {
        uint256 depositAmount = 1000 ether;
        depositDai(depositAmount);

        ILendingPool aave = ILendingPool(aaveProvider.getLendingPool());
        aave.setUserUseReserveAsCollateral(getToken('dai'), false);

        depositDai(depositAmount);

        assertGt(getCollateralAmt(getToken('dai'), address(this)), 0);
    }

    function test_DepositMax() public {
        uint256 depositAmount = 1000 ether;
        vm.prank(getToken('dai'));
        ERC20(getToken('dai')).transfer(address(this), depositAmount);

        execute(getDepositData(getToken('dai'), type(uint256).max));
        assertGt(getCollateralAmt(getToken('dai'), address(this)), 0);
    }

    function test_Borrow() public {
        uint256 depositAmount = 1000 ether;
        depositDai(depositAmount);

        uint256 borrowAmount = 0.1 ether;
        borrowWeth(borrowAmount, 2);
        assertEq(borrowAmount, getBorrowAmt(getToken('weth'), address(this)));
    }

    function test_Payback() public {
        uint256 depositAmount = 1000 ether;
        depositDai(depositAmount);

        uint256 borrowAmount = 0.1 ether;
        borrowWeth(borrowAmount, 2);
        paybackWeth(borrowAmount);

        assertEq(0, getBorrowAmt(getToken('weth'), address(this)));
        assertEq(0, ERC20(getToken('weth')).balanceOf(address(this)));
    }

    function test_PaybackMax() public {
        uint256 depositAmount = 1000 ether;
        depositDai(depositAmount);

        uint256 borrowAmount = 0.1 ether;
        borrowWeth(borrowAmount, 2);
        paybackWeth(type(uint256).max);

        assertEq(0, getBorrowAmt(getToken('weth'), address(this)));
        assertEq(0, ERC20(getToken('weth')).balanceOf(address(this)));
    }

    function test_Withdraw() public {
        uint256 depositAmount = 1000 ether;
        depositDai(depositAmount);

        uint256 borrowAmount = 0.1 ether;
        borrowWeth(borrowAmount, 2);
        paybackWeth(type(uint256).max);
        withdraw(depositAmount);

        assertEq(0, getCollateralAmt(getToken('dai'), address(this)));
    }

    function depositDai(uint256 _amount) public {
        vm.prank(getToken('dai'));
        ERC20(getToken('dai')).transfer(address(this), _amount);

        execute(getDepositData(getToken('dai'), _amount));
    }

    function borrowWeth(uint256 _amount, uint256 _rate) public {
        execute(getBorrowData(getToken('weth'), _amount, _rate));
    }

    function paybackWeth(uint256 _amount) public {
        execute(getPaybackData(_amount, getToken('weth')));
    }

    function withdraw(uint256 _amount) public {
        execute(getWithdrawData(_amount, getToken('dai')));
    }
}
