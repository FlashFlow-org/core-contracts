// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { ERC20 } from 'contracts/dependencies/openzeppelin/contracts/ERC20.sol';

import { DataTypes } from 'contracts/lib/DataTypes.sol';
import { IRouter } from 'contracts/interfaces/IRouter.sol';
import { UniversalERC20 } from 'contracts/lib/UniversalERC20.sol';

import { UniversalPosition } from '../universal-position.sol';
import { DeployPolygonContracts } from '../../../utils/deployer/polygon/polygon.sol';

contract PositionAaveV2Polygon is UniversalPosition, DeployPolygonContracts {
    address public user = makeAddr('user');

    uint256 public leverage = 21000; // 2.1x

    function test_OpenPosition_ClosePosition() public {
        (DataTypes.Position memory position, uint256 index) = openPosition(
            user,
            getToken('dai'),
            getToken('weth'),
            1000 ether,
            leverage,
            address(uniswapConnector),
            address(aaveV2Connector),
            address(balancerFlashloan)
        );

        closePosition(
            user,
            index,
            address(uniswapConnector),
            address(aaveV2Connector),
            address(balancerFlashloan),
            position
        );
    }

    function test_OpenAndClose_TwoPosition() public {
        (DataTypes.Position memory position1, uint256 index1) = openPosition(
            user,
            getToken('dai'),
            getToken('weth'),
            1000 ether,
            leverage,
            address(uniswapConnector),
            address(aaveV2Connector),
            address(balancerFlashloan)
        );

        (DataTypes.Position memory position2, uint256 index2) = openPosition(
            user,
            getToken('dai'),
            getToken('weth'),
            1000 ether,
            leverage,
            address(uniswapConnector),
            address(aaveV2Connector),
            address(balancerFlashloan)
        );

        closePosition(
            user,
            index1,
            address(uniswapConnector),
            address(aaveV2Connector),
            address(balancerFlashloan),
            position1
        );
        closePosition(
            user,
            index2,
            address(uniswapConnector),
            address(aaveV2Connector),
            address(balancerFlashloan),
            position2
        );
    }

    function test_SwapAndOpen_ClosePosition() public {
        vm.prank(user);
        (DataTypes.Position memory position, uint256 index) = swapAndOpen(
            user,
            getToken('weth'),
            getToken('usdc'),
            getToken('dai'),
            2000 ether,
            leverage,
            address(uniswapConnector),
            address(aaveV2Connector),
            address(balancerFlashloan)
        );

        vm.prank(user);
        closePosition(
            user,
            index,
            address(uniswapConnector),
            address(aaveV2Connector),
            address(balancerFlashloan),
            position
        );
    }

    // aave v2 connector integration

    uint256 RATE_TYPE = 2;

    function _getDepositCallData(address _collateral) public view override returns (bytes memory) {
        return abi.encodeWithSelector(aaveV2Connector.deposit.selector, _collateral);
    }

    function _getBorrowCallData(address _debt) public view override returns (bytes memory) {
        return abi.encodeWithSelector(aaveV2Connector.borrow.selector, _debt, RATE_TYPE);
    }

    function _getPaybackCallData(address _debt, uint256 _borrowAmount) public view override returns (bytes memory) {
        return abi.encodeWithSelector(aaveV2Connector.payback.selector, _debt, _borrowAmount, RATE_TYPE);
    }

    function _getWithdrawCallData(
        address _collateral,
        uint256 _collateralAmount
    ) public view override returns (bytes memory) {
        return abi.encodeWithSelector(aaveV2Connector.withdraw.selector, _collateral, _collateralAmount);
    }

    // override
    function getSwapCallData(
        address _fromToken,
        address _toToken,
        address _recipient,
        uint256 _amount
    ) public view override returns (bytes memory data) {
        return _getSwapCallData(_fromToken, _toToken, _recipient, _amount);
    }

    function getQuoteExactInput(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        address _hopToken
    ) public override returns (uint256 amountOut) {
        return quoteExactInput(_tokenIn, _tokenOut, _amountIn, _hopToken);
    }
}
