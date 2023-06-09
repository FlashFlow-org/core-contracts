// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { UniswapConnector } from 'contracts/connectors/bsc/Uniswap.sol';

import { VenusConnector } from 'contracts/connectors/bsc/Venus.sol';

import { UniswapFlashloan } from 'contracts/flashloan/UniswapFlashloan.sol';

import { UniswapHelper } from './uniswap-helper.sol';

contract DeployBscConnectors {
    UniswapConnector public uniswapConnector;

    VenusConnector public venusConnector;

    UniswapFlashloan public uniswapFlashloan;

    function deployConnectors() public returns (string[] memory _names, address[] memory _connectors) {
        _deployExchangeConnectors();
        _deployFlashloanConnectors();
        _deployLendingConnectors();

        _names = new string[](3);
        // lending connectors
        _names[0] = venusConnector.NAME();
        // exchange connectors
        _names[1] = uniswapConnector.NAME();
        // flashloan connectors
        _names[2] = uniswapFlashloan.NAME();

        _connectors = new address[](3);
        // lending connectors
        _connectors[0] = address(venusConnector);
        // exchange connectors
        _connectors[1] = address(uniswapConnector);
        // flashloan connectors
        _connectors[2] = address(uniswapFlashloan);

        return (_names, _connectors);
    }

    function _deployExchangeConnectors() private {
        uniswapConnector = new UniswapConnector();
    }

    function _deployLendingConnectors() private {
        venusConnector = new VenusConnector();
    }

    function _deployFlashloanConnectors() private {
        uniswapFlashloan = new UniswapFlashloan(
            // v3 factory
            0xdB1d10011AD0Ff90774D0C6Bb92e5C5c8b4461F7,
            // weth
            0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
        );
    }
}
