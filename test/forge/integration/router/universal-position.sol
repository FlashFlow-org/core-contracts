// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import 'forge-std/Test.sol';
import { ERC20 } from 'contracts/dependencies/openzeppelin/contracts/ERC20.sol';

import { DataTypes } from 'contracts/lib/DataTypes.sol';
import { PercentageMath } from 'contracts/lib/PercentageMath.sol';
import { PoolAddress } from 'contracts/dependencies/uniswap/libraries/PoolAddress.sol';

import { IRouter } from 'contracts/interfaces/IRouter.sol';
import { IBaseSwap } from 'contracts/interfaces/IBaseSwap.sol';
import { IConnector } from 'contracts/interfaces/IConnector.sol';
import { IBaseFlashloan } from 'contracts/interfaces/IBaseFlashloan.sol';
import { IUniswapFlashloan } from 'contracts/interfaces/connectors/IUniswapFlashloan.sol';

import { UniswapFlashloan } from 'contracts/flashloan/UniswapFlashloan.sol';

import { DeployCoreContracts } from '../../utils/deployer/core.sol';

contract UniversalPosition is DeployCoreContracts {
    function openPosition(
        address _user,
        address _debt,
        address _collateral,
        uint256 _amountIn,
        uint256 _leverage,
        address _swapConnector,
        address _lendingConnector,
        address _flashloanConnector
    ) public returns (DataTypes.Position memory, uint256) {
        DataTypes.Position memory position = DataTypes.Position(_user, _debt, _collateral, _amountIn, _leverage, 0, 0);

        vm.startPrank(position.account);
        deal(position.debt, position.account, position.amountIn);
        ERC20(position.debt).approve(address(router), position.amountIn);
        vm.stopPrank();

        (string memory targetName, bytes memory data) = _getOpenPositionCallData(
            _swapConnector,
            _lendingConnector,
            _flashloanConnector,
            position
        );

        vm.prank(position.account);
        router.openPosition(position, targetName, data);

        uint256 index = router.positionsIndex(position.account);

        return (position, index);
    }

    function swapAndOpen(
        address _user,
        address _debt,
        address _collateral,
        address _swapToken,
        uint256 _swapAmount,
        uint256 _leverage,
        address _swapConnector,
        address _lendingConnector,
        address _flashloanConnector
    ) public returns (DataTypes.Position memory, uint256) {
        IRouter.SwapParams memory params;

        {
            bytes memory swapCallData = getSwapCallData(_swapToken, _debt, address(router), _swapAmount);
            params = IRouter.SwapParams(_swapToken, _debt, _swapAmount, 'UniswapAuto', swapCallData);
        }

        uint256 amountIn = getQuoteExactInput(_swapToken, _debt, _swapAmount, address(0));

        DataTypes.Position memory position = DataTypes.Position(_user, _debt, _collateral, amountIn, _leverage, 0, 0);

        vm.startPrank(position.account);
        deal(_swapToken, position.account, _swapAmount);
        ERC20(_swapToken).approve(address(router), _swapAmount);
        vm.stopPrank();

        (string memory targetName, bytes memory data) = _getOpenPositionCallData(
            _swapConnector,
            _lendingConnector,
            _flashloanConnector,
            position
        );

        vm.prank(position.account);
        router.swapAndOpen(position, targetName, data, params);

        uint256 index = router.positionsIndex(position.account);

        return (position, index);
    }

    function closePosition(
        address _user,
        uint256 _indexPosition,
        address _swapConnector,
        address _lendingConnector,
        address _flashloanConnector,
        DataTypes.Position memory _position
    ) public {
        bytes32 key = router.getKey(_position.account, _indexPosition);
        (, , , , , , uint256 borrowAmount) = router.positions(key);

        (string memory targetName, bytes memory data) = _getClosePositionCallData(
            key,
            _swapConnector,
            _lendingConnector,
            _flashloanConnector,
            _position
        );

        vm.prank(_user);
        router.closePosition(key, _position.debt, borrowAmount, targetName, data);
    }

    function _getOpenPositionCallData(
        address _swapConnector,
        address _lendingConnector,
        address _flashloanConnector,
        DataTypes.Position memory _position
    ) public returns (string memory, bytes memory) {
        uint256 loanAmt = getLoanAmount(_position.amountIn, _position.leverage);

        string memory targetName = getFlashloanData(_flashloanConnector, _position.debt, loanAmt);
        bytes memory _calldata = _getOpenPositionCallbackCallData(_swapConnector, _lendingConnector, _position);

        uint256 chainId = getChainID();
        if (chainId == 56) {
            // hardcode becasuse serach pool on the UI side
            IUniswapFlashloan.FlashParams memory params = IUniswapFlashloan.FlashParams(
                PoolAddress.PoolKey(_position.debt, 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d, 100),
                loanAmt,
                0
            );

            _calldata = abi.encode(params, _calldata);
            targetName = 'UniswapFlashloan';
        }

        return (targetName, _calldata);
    }

    function _getClosePositionCallData(
        bytes32 _key,
        address _swapConnector,
        address _lendingConnector,
        address _flashloanConnector,
        DataTypes.Position memory _position
    ) public returns (string memory, bytes memory) {
        (, , , , , , uint256 borrowAmount) = router.positions(_key);

        string memory targetName = getFlashloanData(_flashloanConnector, _position.debt, borrowAmount);
        bytes memory _calldata = _getClosePositionCallbackCallData(_swapConnector, _lendingConnector, _position, _key);

        uint256 chainId = getChainID();
        if (chainId == 56) {
            // hardcode becasuse serach pool on the UI side
            IUniswapFlashloan.FlashParams memory params = IUniswapFlashloan.FlashParams(
                PoolAddress.PoolKey(_position.debt, 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d, 100),
                borrowAmount,
                0
            );

            _calldata = abi.encode(params, _calldata);
            targetName = 'UniswapFlashloan';
        }

        return (targetName, _calldata);
    }

    function _getOpenPositionCallbackCallData(
        address _swapConnector,
        address _lendingConnector,
        DataTypes.Position memory _position
    ) public view returns (bytes memory callData) {
        string[] memory targetNames = _getOpenConnectorNames(_swapConnector, _lendingConnector);
        bytes[] memory datas = _getOpenConnectorDatas(_position);
        bytes[] memory customDatas = _getOpenCustomCallData(_position.account);

        callData = abi.encode(accountImpl.openPositionCallback.selector, targetNames, datas, customDatas);
    }

    function _getClosePositionCallbackCallData(
        address _swapConnector,
        address _lendingConnector,
        DataTypes.Position memory _position,
        bytes32 _positionKey
    ) public view returns (bytes memory callData) {
        string[] memory targetNames = _getCloseConnectorNames(_swapConnector, _lendingConnector);
        bytes[] memory datas = _getCloseConnectorDatas(_position, _positionKey);
        bytes[] memory customDatas = _getCloseCustomCallData(_positionKey);

        callData = abi.encode(accountImpl.closePositionCallback.selector, targetNames, datas, customDatas);
    }

    function _getOpenCustomCallData(address _account) public view returns (bytes[] memory) {
        bytes[] memory _customDatas = new bytes[](1);
        _customDatas[0] = abi.encode(_getPositionKey(_account));

        return _customDatas;
    }

    function _getCloseCustomCallData(bytes32 _positionKey) public pure returns (bytes[] memory) {
        bytes[] memory _customDatas = new bytes[](1);
        _customDatas[0] = abi.encode(_positionKey);

        return _customDatas;
    }

    function _getOpenConnectorNames(
        address _swapConnector,
        address _lendingConnector
    ) public view returns (string[] memory names) {
        names = new string[](3);
        names[0] = IConnector(_swapConnector).NAME();
        names[1] = IConnector(_lendingConnector).NAME();
        names[2] = IConnector(_lendingConnector).NAME();
    }

    function _getCloseConnectorNames(
        address _swapConnector,
        address _lendingConnector
    ) public view returns (string[] memory names) {
        names = new string[](3);
        names[0] = IConnector(_lendingConnector).NAME();
        names[1] = IConnector(_lendingConnector).NAME();
        names[2] = IConnector(_swapConnector).NAME();
    }

    function _getOpenConnectorDatas(DataTypes.Position memory _position) public view returns (bytes[] memory datas) {
        (address recipient, uint256 amount) = _getRecipientAndAmount(_position);

        datas = new bytes[](3);
        datas[0] = getSwapCallData(_position.debt, _position.collateral, recipient, amount);
        datas[1] = _getDepositCallData(_position.collateral);
        datas[2] = _getBorrowCallData(_position.debt);
    }

    function _getCloseConnectorDatas(
        DataTypes.Position memory _position,
        bytes32 _positionKey
    ) public view returns (bytes[] memory datas) {
        (address recipient, ) = _getRecipientAndAmount(_position);
        (, , , , , uint256 collateralAmount, uint256 borrowAmount) = router.positions(_positionKey);

        datas = new bytes[](3);
        datas[0] = _getPaybackCallData(_position.debt, borrowAmount);
        datas[1] = _getWithdrawCallData(_position.collateral, collateralAmount);
        datas[2] = getSwapCallData(_position.collateral, _position.debt, recipient, collateralAmount);
    }

    function _getUserAccountAddress(address _user) public view returns (address account) {
        account = router.accounts(_user);

        if (account == address(0)) {
            account = router.predictDeterministicAddress(_user);
        }
    }

    function _getPositionKey(address _user) public view returns (bytes32 key) {
        uint256 index = router.positionsIndex(_user);
        key = router.getKey(_user, index + 1);
    }

    function _getRecipientAndAmount(DataTypes.Position memory _position) public view returns (address, uint256) {
        address recipient = _getUserAccountAddress(_position.account);
        uint256 loanAmt = getLoanAmount(_position.amountIn, _position.leverage);

        uint256 swapAmount = loanAmt + _position.amountIn;
        uint256 fee = router.getFeeAmount(swapAmount);
        uint256 swapAmountWithoutFee = swapAmount - fee;

        return (recipient, swapAmountWithoutFee);
    }

    function getLoanAmount(uint256 _amount, uint256 _leverage) public pure returns (uint256 amount) {
        // leverage - 1 = position size without user amount
        amount = (_amount * (_leverage - PercentageMath.PERCENTAGE_FACTOR)) / PercentageMath.PERCENTAGE_FACTOR;
    }

    function getFlashloanData(address _connector, address lT, uint256 lA) public returns (string memory targetName) {
        if (IBaseFlashloan(_connector).getAvailability(lT, lA)) {
            targetName = IBaseFlashloan(_connector).NAME();
        }
    }

    // virtual function

    function _getDepositCallData(address _collateral) public view virtual returns (bytes memory) {}

    function _getBorrowCallData(address _debt) public view virtual returns (bytes memory) {}

    function _getPaybackCallData(address _debt, uint256 _borrowAmount) public view virtual returns (bytes memory) {}

    function _getWithdrawCallData(
        address _collateral,
        uint256 _collateralAmount
    ) public view virtual returns (bytes memory) {}

    function getSwapCallData(
        address _fromToken,
        address _toToken,
        address _recipient,
        uint256 _amount
    ) public view virtual returns (bytes memory data) {}

    function getQuoteExactInput(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        address _hopToken
    ) public virtual returns (uint256 amountOut) {}
}
