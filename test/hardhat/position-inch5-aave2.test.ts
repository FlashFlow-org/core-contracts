import { ethers } from 'hardhat';
import { solidity } from 'ethereum-waffle';
import chai from 'chai';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address';
import { BigNumber } from 'ethers';
import { ERC20, Router, AaveV2Connector, FlashResolver, Account, InchV5Connector } from '../../typechain-types';

import { inchCalldata, getSignerFromAddress, openCalldata, uniSwap } from './utils';

chai.use(solidity);
const { expect } = chai;

const DAI_CONTRACT = '0x6B175474E89094C44Da98b954EedeAC495271d0F';
const USDC_CONTRACT = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48';
const ETH_CONTRACT = '0x0000000000000000000000000000000000000000';
const ETH_CONTRACT_2 = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';
const WETH_CONTRACT = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';

const MAX_UINT = '115792089237316195423570985008687907853269984665640564039457584007913129639935';

const DEFAULT_AMOUNT = ethers.utils.parseEther('1000');
const FEE = BigNumber.from('3'); // 0.03%
const LEVERAGE = BigNumber.from('2');

const encoder = new ethers.utils.AbiCoder();

describe('Open and close (inchv5 - aave2)', async () => {
  // wallets
  let owner: SignerWithAddress;
  let other: SignerWithAddress;
  let daiContract: ERC20;
  let wethContract: ERC20;

  // contracts
  let routerContract: Router;
  let accountContract: Account;
  let flashResolverContract: FlashResolver;
  let inchV5ConnectorContract: InchV5Connector;
  let aveV2ConnectorContract: AaveV2Connector;

  // others
  let openPositionCallback: string;
  let closePositionCallback: string;

  beforeEach(async () => {
    [owner, other] = await ethers.getSigners();

    daiContract = (await ethers.getContractAt(
      'contracts/dependencies/openzeppelin/contracts/IERC20.sol:IERC20',
      DAI_CONTRACT,
    )) as ERC20;

    wethContract = (await ethers.getContractAt(
      'contracts/dependencies/openzeppelin/contracts/IERC20.sol:IERC20',
      WETH_CONTRACT,
    )) as unknown as ERC20;

    daiContract = await daiContract.connect(await getSignerFromAddress('0xb527a981e1d415af696936b3174f2d7ac8d11369'));

    await daiContract.transfer(owner.address, DEFAULT_AMOUNT.mul(5));

    const addressesProviderFactory = await ethers.getContractFactory('AddressesProvider');
    const addressesProvider = await addressesProviderFactory.deploy(owner.address);
    await addressesProvider.deployed();

    await addressesProvider.connect(owner).setAddress(ethers.utils.formatBytes32String('ACL_ADMIN'), owner.address);

    const aclManagerFactory = await ethers.getContractFactory('ACLManager');
    const aclManager = await aclManagerFactory.deploy(addressesProvider.address);
    await aclManager.deployed();

    const connectorsFactory = await ethers.getContractFactory('Connectors');
    const connectors = await connectorsFactory.deploy(addressesProvider.address);
    await connectors.deployed();

    await aclManager.connect(owner).addConnectorAdmin(owner.address);
    await aclManager.connect(owner).addRouterAdmin(owner.address);

    await addressesProvider
      .connect(owner)
      .setAddress(ethers.utils.formatBytes32String('ACL_MANAGER'), aclManager.address);
    await addressesProvider
      .connect(owner)
      .setAddress(ethers.utils.formatBytes32String('CONNECTORS'), connectors.address);

    const configuratorFactory = await ethers.getContractFactory('Configurator');
    const configurator = await configuratorFactory.deploy();
    await configurator.deployed();

    const routerFactory = await ethers.getContractFactory('Router');
    const router = await routerFactory.deploy(addressesProvider.address);
    await router.deployed();

    await addressesProvider.connect(owner).setRouterImpl(router.address);
    await addressesProvider.connect(owner).setConfiguratorImpl(configurator.address);

    const configuratorProxy = await addressesProvider.getConfigurator();
    const routerProxy = await addressesProvider.getRouter();

    routerContract = await ethers.getContractAt('Router', routerProxy);

    const InchV5ConnectorFactory = await ethers.getContractFactory('InchV5Connector');
    const InchV5Connector = await InchV5ConnectorFactory.deploy();
    await InchV5Connector.deployed();

    inchV5ConnectorContract = InchV5Connector;

    const UniswapConnectorFactory = await ethers.getContractFactory('UniswapConnector');
    const UniswapConnector = await UniswapConnectorFactory.deploy();
    await UniswapConnector.deployed();

    const AaveV2ConnectorFactory = await ethers.getContractFactory('AaveV2Connector');
    const AaveV2Connector = await AaveV2ConnectorFactory.deploy();
    await AaveV2Connector.deployed();

    aveV2ConnectorContract = AaveV2Connector;

    const AaveV3ConnectorFactory = await ethers.getContractFactory('AaveV3Connector');
    const AaveV3Connector = await AaveV3ConnectorFactory.deploy();
    await AaveV3Connector.deployed();

    const CompoundV3ConnectorFactory = await ethers.getContractFactory('CompoundV3Connector');
    const CompoundV3Connector = await CompoundV3ConnectorFactory.deploy();
    await CompoundV3Connector.deployed();

    const CompoundV2ConnectorFactory = await ethers.getContractFactory('CompoundV2Connector');
    const CompoundV2Connector = await CompoundV2ConnectorFactory.deploy();
    await CompoundV2Connector.deployed();

    const configuratorContrcat = await ethers.getContractAt('Configurator', configuratorProxy);
    await configuratorContrcat
      .connect(owner)
      .addConnectors(
        [
          await InchV5Connector.callStatic.NAME(),
          await UniswapConnector.callStatic.NAME(),
          await AaveV2Connector.callStatic.NAME(),
          await AaveV3Connector.callStatic.NAME(),
          await CompoundV3Connector.callStatic.NAME(),
          await CompoundV2Connector.callStatic.NAME(),
        ],
        [
          InchV5Connector.address,
          UniswapConnector.address,
          AaveV2Connector.address,
          AaveV3Connector.address,
          CompoundV3Connector.address,
          CompoundV2Connector.address,
        ],
      );

    const flashAggregatorFactory = await ethers.getContractFactory('FlashAggregator');
    const flashAggregator = await flashAggregatorFactory.deploy();
    await flashAggregator.deployed();

    const flashResolverFactory = await ethers.getContractFactory('FlashResolver');
    const flashResolver = await flashResolverFactory.deploy(flashAggregator.address);
    await flashResolver.deployed();
    flashResolverContract = flashResolver;

    const accountFactory = await ethers.getContractFactory('Account');
    const account = await accountFactory.deploy(addressesProvider.address);
    await account.deployed();
    accountContract = account;

    const proxyFactory = await ethers.getContractFactory('contracts/Proxy.sol:Proxy');
    const proxy = await proxyFactory.deploy(addressesProvider.address);
    await proxy.deployed();

    await addressesProvider.connect(owner).setAddress(ethers.utils.formatBytes32String('ACCOUNT'), account.address);

    await addressesProvider.connect(owner).setAddress(ethers.utils.formatBytes32String('TREASURY'), owner.address);

    await addressesProvider.connect(owner).setAddress(ethers.utils.formatBytes32String('ACCOUNT_PROXY'), proxy.address);

    await addressesProvider
      .connect(owner)
      .setAddress(ethers.utils.formatBytes32String('FLASHLOAN_AGGREGATOR'), flashAggregator.address);

    openPositionCallback = account.interface.getSighash('openPositionCallback(string[],bytes[],bytes[],uint256)');

    closePositionCallback = account.interface.getSighash('closePositionCallback(string[],bytes[],bytes[],uint256)');
  });

  it('swap and open - close position', async () => {
    const RATE_TYPE_AAVE = 1;

    const shortAmount = ethers.utils.parseEther('1').mul(2);

    const [swapCalldata, toTokenAmount] = await inchCalldata({
      fromAddress: routerContract.address,
      fromToken: ETH_CONTRACT_2,
      toToken: WETH_CONTRACT,
      amount: shortAmount.toString(),
      slippage: 5,
    });

    const calldataForConnector = inchV5ConnectorContract.interface.encodeFunctionData('swap', [
      WETH_CONTRACT,
      ETH_CONTRACT_2,
      shortAmount._hex,
      swapCalldata as string,
    ]);

    const swapParams = {
      fromToken: ETH_CONTRACT_2,
      toToken: WETH_CONTRACT,
      amount: shortAmount.toString(),
      targetName: 'OneInchV5',
      data: calldataForConnector,
    };

    const position = {
      account: owner.address,
      debt: WETH_CONTRACT,
      collateral: USDC_CONTRACT,
      // @ts-ignore
      amountIn: BigNumber.from(toTokenAmount),
      leverage: LEVERAGE,
      collateralAmount: 0,
      borrowAmount: 0,
    };

    const swapAmount = position.amountIn.mul(position.leverage);
    const swapAmountWithoutFee = swapAmount.sub(swapAmount.mul(FEE).div(10000)).toHexString();

    const [openSwapCalldata] = await inchCalldata({
      fromAddress: routerContract.address, // from user account
      fromToken: position.debt,
      toToken: position.collateral,
      amount: swapAmount.sub(swapAmount.mul(FEE).div(10000)).toString(),
      slippage: 5,
    });

    const _tokens = [position.debt];
    const _amts = [position.amountIn.mul(position.leverage.sub(1))];

    const { bestRoutes: bestOpenRoutes } = await flashResolverContract.callStatic.getData(_tokens, _amts);

    const positionSwapCalldata = inchV5ConnectorContract.interface.encodeFunctionData('swap', [
      position.collateral,
      position.debt,
      swapAmountWithoutFee,
      openSwapCalldata as string,
    ]);

    const dData = aveV2ConnectorContract.interface.encodeFunctionData('deposit', [position.collateral, 0]);
    const deposit = `${dData.slice(0, 74)}`; // 10 byte = (0x and sig hash) 64 byte = (1 params)

    const bData = aveV2ConnectorContract.interface.encodeFunctionData('borrow', [position.debt, RATE_TYPE_AAVE, 0]);
    const borrow = `${bData.slice(0, 138)}`; // 10 byte = (0x and sig hash) 128 byte = (1 and 2 params)

    const key = await routerContract.getKey(owner.address, '0x1'); // first index after open position is 1

    const calldataOpen = encoder.encode(
      ['bytes4', 'string[]', 'bytes[]', 'bytes[]'],
      [openPositionCallback, ['OneInchV5', 'AaveV2', 'AaveV2'], [positionSwapCalldata, deposit, borrow], [key]],
    );

    await routerContract.connect(owner).swapAndOpen(position, bestOpenRoutes[0], calldataOpen, swapParams, {
      value: shortAmount._hex,
    });

    const { collateralAmount, borrowAmount } = await routerContract.callStatic.positions(key);

    const [closeSwapCalldata] = await inchCalldata({
      fromAddress: routerContract.address, // from user account
      fromToken: position.collateral,
      toToken: position.debt,
      amount: collateralAmount.toString(),
      slippage: 5,
    });

    const positionCloseSwapCalldata = inchV5ConnectorContract.interface.encodeFunctionData('swap', [
      position.debt,
      position.collateral,
      collateralAmount.toString(),
      closeSwapCalldata as string,
    ]);

    // using max uint becase i don't want calculate borrow amount + borrow fee
    const payback = aveV2ConnectorContract.interface.encodeFunctionData('payback', [
      position.debt,
      MAX_UINT,
      RATE_TYPE_AAVE,
    ]);
    const withdraw = aveV2ConnectorContract.interface.encodeFunctionData('withdraw', [
      position.collateral,
      collateralAmount,
    ]);

    const calldataClose = encoder.encode(
      ['bytes4', 'string[]', 'bytes[]', 'bytes[]'],
      [closePositionCallback, ['AaveV2', 'AaveV2', 'OneInchV5'], [payback, withdraw, positionCloseSwapCalldata], [key]],
    );

    // bump flashloan amount beacase borrow amount + fee gt than borrow amount
    const flashloanAmount = borrowAmount.mul(1005).div(1000);
    const { bestRoutes: closeRoutes } = await flashResolverContract.callStatic.getData(
      [position.debt],
      [flashloanAmount],
    );

    await routerContract
      .connect(owner)
      .closePosition(key, position.debt, flashloanAmount, closeRoutes[0], calldataClose);
  });
});
