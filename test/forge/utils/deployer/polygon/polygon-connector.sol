// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { UniswapConnector } from 'contracts/connectors/polygon/Uniswap.sol';

import { AaveV2Connector } from 'contracts/connectors/polygon/AaveV2.sol';
import { AaveV3Connector } from 'contracts/connectors/polygon/AaveV3.sol';

import { AaveV2Flashloan } from 'contracts/flashloan/AaveV2Flashloan.sol';
import { AaveV3Flashloan } from 'contracts/flashloan/AaveV3Flashloan.sol';
import { BalancerFlashloan } from 'contracts/flashloan/BalancerFlashloan.sol';
import { UniswapFlashloan } from 'contracts/flashloan/UniswapFlashloan.sol';

contract DeployPolygonConnectors {
    UniswapConnector public uniswapConnector;

    AaveV2Connector public aaveV2Connector;
    AaveV3Connector public aaveV3Connector;

    AaveV2Flashloan public aaveV2Flashloan;
    AaveV3Flashloan public aaveV3Flashloan;
    BalancerFlashloan public balancerFlashloan;
    UniswapFlashloan public uniswapFlashloan;

    function deployConnectors() public returns (string[] memory _names, address[] memory _connectors) {
        _deployExchangeConnectors();
        _deployFlashloanConnectors();
        _deployLendingConnectors();

        _names = new string[](7);
        // lending connectors
        _names[0] = aaveV2Connector.NAME();
        _names[1] = aaveV3Connector.NAME();
        // exchange connectors
        _names[2] = uniswapConnector.NAME();
        // flashloan connectors
        _names[3] = aaveV2Flashloan.NAME();
        _names[4] = aaveV3Flashloan.NAME();
        _names[5] = balancerFlashloan.NAME();
        _names[6] = uniswapFlashloan.NAME();

        _connectors = new address[](7);
        // lending connectors
        _connectors[0] = address(aaveV2Connector);
        _connectors[1] = address(aaveV3Connector);
        // exchange connectors
        _connectors[2] = address(uniswapConnector);
        // flashloan connectors
        _connectors[3] = address(aaveV2Flashloan);
        _connectors[4] = address(aaveV3Flashloan);
        _connectors[5] = address(balancerFlashloan);
        _connectors[6] = address(uniswapFlashloan);

        return (_names, _connectors);
    }

    function _deployExchangeConnectors() private {
        uniswapConnector = new UniswapConnector();
    }

    function _deployLendingConnectors() private {
        aaveV2Connector = new AaveV2Connector();
        aaveV3Connector = new AaveV3Connector();
    }

    function _deployFlashloanConnectors() private {
        aaveV2Flashloan = new AaveV2Flashloan(
            // aave lending pool v2
            0x8dFf5E27EA6b7AC08EbFdf9eB090F32ee9a30fcf,
            // aave pool data provider v2
            0x7551b5D2763519d4e37e8B81929D336De671d46d
        );
        aaveV3Flashloan = new AaveV3Flashloan(
            // aave lending pool v3
            0x794a61358D6845594F94dc1DB02A252b5b4814aD,
            // aave pool data provider v3
            0x69FA688f1Dc47d4B5d8029D5a35FB7a548310654
        );
        // Balancer Vault v2
        balancerFlashloan = new BalancerFlashloan(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
        uniswapFlashloan = new UniswapFlashloan(
            // v3 factory
            0x1F98431c8aD98523631AE4a59f267346ea31F984,
            // weth
            0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619
        );
    }
}
