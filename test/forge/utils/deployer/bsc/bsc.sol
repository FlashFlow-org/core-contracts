// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { DeployCoreContracts } from '../core.sol';
import { DeployBscConnectors } from './bsc-connector.sol';
import { UniswapHelper } from './uniswap-helper.sol';

contract DeployBscContracts is DeployCoreContracts, DeployBscConnectors, UniswapHelper {
    function setUp() public {
        string memory url = vm.rpcUrl('bsc');
        uint256 forkId = vm.createFork(url);
        vm.selectFork(forkId);

        (string[] memory names, address[] memory connectors) = deployConnectors();
        deployContracts(names, connectors);
    }
}
