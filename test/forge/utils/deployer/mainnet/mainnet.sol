// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { DeployCoreContracts } from '../core.sol';
import { DeployMainnetConnectors } from './mainnet-connector.sol';
import { UniswapHelper } from './uniswap-helper.sol';

contract DeployMainnetContracts is DeployCoreContracts, DeployMainnetConnectors, UniswapHelper {
    function setUp() public {
        string memory url = vm.rpcUrl('mainnet');
        uint256 forkId = vm.createFork(url);
        vm.selectFork(forkId);

        (string[] memory names, address[] memory connectors) = deployConnectors();
        deployContracts(names, connectors);
    }
}
