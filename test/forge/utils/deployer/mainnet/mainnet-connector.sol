// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { InchV5Connector } from 'contracts/connectors/InchV5.sol';
import { UniswapConnector } from 'contracts/connectors/mainnet/Uniswap.sol';

import { AaveV2Connector } from 'contracts/connectors/mainnet/AaveV2.sol';
import { AaveV3Connector } from 'contracts/connectors/mainnet/AaveV3.sol';
import { CompoundV2Connector } from 'contracts/connectors/mainnet/CompoundV2.sol';
import { CompoundV3Connector } from 'contracts/connectors/CompoundV3.sol';

import { AaveV2Flashloan } from 'contracts/flashloan/AaveV2Flashloan.sol';
import { AaveV3Flashloan } from 'contracts/flashloan/AaveV3Flashloan.sol';
import { MakerFlashloan } from 'contracts/flashloan/MakerFlashloan.sol';
import { BalancerFlashloan } from 'contracts/flashloan/BalancerFlashloan.sol';
import { UniswapFlashloan } from 'contracts/flashloan/UniswapFlashloan.sol';

contract DeployMainnetConnectors {
    InchV5Connector public inchV5Connector;
    UniswapConnector public uniswapConnector;

    AaveV2Connector public aaveV2Connector;
    AaveV3Connector public aaveV3Connector;
    CompoundV3Connector public compoundV3Connector;
    CompoundV2Connector public compoundV2Connector;

    MakerFlashloan public makerFlashloan;
    AaveV2Flashloan public aaveV2Flashloan;
    AaveV3Flashloan public aaveV3Flashloan;
    BalancerFlashloan public balancerFlashloan;
    UniswapFlashloan public uniswapFlashloan;

    function deployConnectors() public returns (string[] memory _names, address[] memory _connectors) {
        _deployExchangeConnectors();
        _deployFlashloanConnectors();
        _deployLendingConnectors();

        _names = new string[](11);
        // lending connectors
        _names[0] = aaveV2Connector.NAME();
        _names[1] = aaveV3Connector.NAME();
        _names[2] = compoundV2Connector.NAME();
        _names[3] = compoundV3Connector.NAME();
        // exchange connectors
        _names[4] = inchV5Connector.NAME();
        _names[5] = uniswapConnector.NAME();
        // flashloan connectors
        _names[6] = aaveV2Flashloan.NAME();
        _names[7] = aaveV3Flashloan.NAME();
        _names[8] = balancerFlashloan.NAME();
        _names[9] = makerFlashloan.NAME();
        _names[10] = uniswapFlashloan.NAME();

        _connectors = new address[](11);
        // lending connectors
        _connectors[0] = address(aaveV2Connector);
        _connectors[1] = address(aaveV3Connector);
        _connectors[2] = address(compoundV2Connector);
        _connectors[3] = address(compoundV3Connector);
        // exchange connectors
        _connectors[4] = address(inchV5Connector);
        _connectors[5] = address(uniswapConnector);
        // flashloan connectors
        _connectors[6] = address(aaveV2Flashloan);
        _connectors[7] = address(aaveV3Flashloan);
        _connectors[8] = address(balancerFlashloan);
        _connectors[9] = address(makerFlashloan);
        _connectors[10] = address(uniswapFlashloan);

        return (_names, _connectors);
    }

    function _deployExchangeConnectors() private {
        inchV5Connector = new InchV5Connector();
        uniswapConnector = new UniswapConnector();
    }

    function _deployLendingConnectors() private {
        aaveV2Connector = new AaveV2Connector();
        aaveV3Connector = new AaveV3Connector();
        compoundV3Connector = new CompoundV3Connector();
        compoundV2Connector = new CompoundV2Connector();
    }

    function _deployFlashloanConnectors() private {
        aaveV2Flashloan = new AaveV2Flashloan(
            // aave lending pool v2
            0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9,
            // aave pool data provider v2
            0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d
        );
        aaveV3Flashloan = new AaveV3Flashloan(
            // aave lending pool v3
            0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2,
            // aave pool data provider v3
            0x7B4EB56E7CD4b454BA8ff71E4518426369a138a3
        );
        // Balancer Vault v2 eth
        balancerFlashloan = new BalancerFlashloan(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
        makerFlashloan = new MakerFlashloan(
            // DssFlash
            0x1EB4CF3A948E7D72A198fe073cCb8C7a948cD853,
            // dai token eth
            0x6B175474E89094C44Da98b954EedeAC495271d0F
        );
        uniswapFlashloan = new UniswapFlashloan(
            // v3 factory
            0x1F98431c8aD98523631AE4a59f267346ea31F984,
            // weth
            0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
        );
    }
}
