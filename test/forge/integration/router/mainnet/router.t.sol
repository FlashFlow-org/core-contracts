// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { ERC20 } from 'contracts/dependencies/openzeppelin/contracts/ERC20.sol';
import { Clones } from 'contracts/dependencies/openzeppelin/upgradeability/Clones.sol';

import { DataTypes } from 'contracts/lib/DataTypes.sol';
import { IAddressesProvider } from 'contracts/interfaces/IAddressesProvider.sol';

import { IRouter } from 'contracts/interfaces/IRouter.sol';
import { IBaseSwap } from 'contracts/interfaces/IBaseSwap.sol';

import { UniswapConnector } from 'contracts/connectors/mainnet/Uniswap.sol';

import { Router } from 'contracts/Router.sol';
import { Connectors } from 'contracts/Connectors.sol';
import { ACLManager } from 'contracts/ACLManager.sol';
import { Configurator } from 'contracts/Configurator.sol';
import { AddressesProvider } from 'contracts/AddressesProvider.sol';

import { Tokens } from '../../../utils/tokens.sol';
import { UniswapHelper } from '../../../utils/deployer/mainnet/uniswap-helper.sol';

contract TestRouterSwapMainnet is UniswapHelper, Tokens {
    Router router;
    Connectors connectors;
    Configurator configurator;
    ACLManager aclManager;
    AddressesProvider addressesProvider;

    address testAddress;

    function test_swapDaiToWeth() public {
        uint256 amount = 1000 ether;

        address fromToken = getToken('dai');
        address toToken = getToken('weth');

        deal(fromToken, address(this), amount);

        ERC20(fromToken).approve(address(router), amount);

        bytes memory swapdata = getUniSwapCallData(fromToken, toToken, address(this), amount);
        bytes memory data = abi.encodeWithSelector(IBaseSwap.swap.selector, toToken, fromToken, amount, swapdata);
        router.swap(IRouter.SwapParams(fromToken, toToken, amount, 'UniswapAuto', data));

        assertTrue(ERC20(toToken).balanceOf(address(this)) > 0);
    }

    function test_swapDaiToWeth_Revert() public {
        uint256 amount = 1000 ether;

        address fromToken = getToken('dai');
        address toToken = getToken('weth');

        deal(fromToken, address(this), amount);

        ERC20(fromToken).approve(address(router), amount);

        bytes memory swapdata = getUniSwapCallData(fromToken, toToken, address(this), amount);
        bytes memory data = abi.encodeWithSelector(IBaseSwap.swap.selector, toToken, fromToken, amount, swapdata);

        vm.expectRevert(bytes(''));
        router.swap(IRouter.SwapParams(fromToken, toToken, amount, 'UniswapAuto', abi.encode(uint(123), data)));
    }

    receive() external payable {}

    function setUp() public {
        string memory url = vm.rpcUrl('mainnet');
        uint256 forkId = vm.createFork(url);
        vm.selectFork(forkId);

        addressesProvider = new AddressesProvider(address(this));
        addressesProvider.setAddress(bytes32('ACL_ADMIN'), address(this));

        aclManager = new ACLManager(IAddressesProvider(address(addressesProvider)));
        connectors = new Connectors(address(addressesProvider));

        aclManager.addConnectorAdmin(address(this));
        aclManager.addRouterAdmin(address(this));

        addressesProvider.setAddress(bytes32('ACL_MANAGER'), address(aclManager));
        addressesProvider.setAddress(bytes32('CONNECTORS'), address(connectors));

        configurator = new Configurator();

        router = new Router(IAddressesProvider(address(addressesProvider)));
        addressesProvider.setRouterImpl(address(router));
        addressesProvider.setConfiguratorImpl(address(configurator));

        configurator = Configurator(addressesProvider.getConfigurator());
        router = Router(payable(addressesProvider.getRouter()));

        UniswapConnector swapConnector = new UniswapConnector();

        string[] memory _names = new string[](1);
        _names[0] = swapConnector.NAME();

        address[] memory _addresses = new address[](1);
        _addresses[0] = address(swapConnector);

        configurator.addConnectors(_names, _addresses);
    }
}
