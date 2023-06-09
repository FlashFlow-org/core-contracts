import { ethers } from 'hardhat';
import { solidity } from 'ethereum-waffle';
import chai from 'chai';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address';
import { BigNumber } from 'ethers';
import { ERC20, Router, InchV5Connector } from '../../typechain-types';

import { inchCalldata, getSignerFromAddress } from './utils';

chai.use(solidity);
const { expect } = chai;

const USDC_CONTRACT = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48';
const DAI_CONTRACT = '0x6B175474E89094C44Da98b954EedeAC495271d0F';
const ETH_CONTRACT_2 = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';

const MAX_UINT = '115792089237316195423570985008687907853269984665640564039457584007913129639935';

const DEFAULT_AMOUNT = ethers.utils.parseUnits('1000');

describe('OneInch v5 connector', async () => {
  // wallets
  let owner: SignerWithAddress;
  let other: SignerWithAddress;
  let daiContract: ERC20;

  // contracts
  let inchV5Connector: InchV5Connector;

  beforeEach(async () => {
    [owner, other] = await ethers.getSigners();

    daiContract = (await ethers.getContractAt(
      'contracts/dependencies/openzeppelin/contracts/IERC20.sol:IERC20',
      DAI_CONTRACT,
    )) as ERC20;

    daiContract = await daiContract.connect(await getSignerFromAddress('0xb527a981e1d415af696936b3174f2d7ac8d11369'));

    await daiContract.transfer(owner.address, DEFAULT_AMOUNT.mul(5));

    const inchV5ConnectorFactory = await ethers.getContractFactory('InchV5Connector');
    inchV5Connector = await inchV5ConnectorFactory.deploy();
    await inchV5Connector.deployed();
  });

  it('Swap ETH to USDC', async () => {
    const swapAmount = ethers.utils.parseEther('10');

    const [calldata] = await inchCalldata({
      fromAddress: inchV5Connector.address,
      fromToken: ETH_CONTRACT_2,
      toToken: DAI_CONTRACT,
      amount: swapAmount.toString(),
      slippage: 5,
    });

    await inchV5Connector
      .connect(other)
      .swap(DAI_CONTRACT, ETH_CONTRACT_2, swapAmount, calldata as string, { value: swapAmount });

    expect(
      parseInt(ethers.utils.formatEther((await daiContract.callStatic.balanceOf(inchV5Connector.address)).toString())),
    ).to.greaterThan(0);
  });

  it('Swap DAI to ETH', async () => {
    const swapAmount = ethers.utils.parseEther('1000');

    const [calldata] = await inchCalldata({
      fromAddress: inchV5Connector.address,
      fromToken: DAI_CONTRACT,
      toToken: ETH_CONTRACT_2,
      amount: swapAmount.toString(),
      slippage: 5,
    });

    await daiContract.transfer(inchV5Connector.address, swapAmount);

    await inchV5Connector.connect(other).swap(ETH_CONTRACT_2, DAI_CONTRACT, swapAmount, calldata as string);

    expect(
      parseInt(ethers.utils.formatEther((await ethers.provider.getBalance(inchV5Connector.address)).toString())),
    ).to.greaterThan(0);
  });
});
