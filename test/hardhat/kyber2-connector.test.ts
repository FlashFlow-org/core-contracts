import { ethers } from 'hardhat';
import { solidity } from 'ethereum-waffle';
import chai from 'chai';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/dist/src/signer-with-address';
import { ERC20, KyberV2Connector } from '../../typechain-types';

import { kyberCalldata, getSignerFromAddress } from './utils';

chai.use(solidity);
const { expect } = chai;

const DAI_CONTRACT = '0x6B175474E89094C44Da98b954EedeAC495271d0F';
const ETH_CONTRACT_2 = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';

const DEFAULT_AMOUNT = ethers.utils.parseUnits('1000');

describe('Kyber v2 connector', async () => {
  // wallets
  let owner: SignerWithAddress;
  let other: SignerWithAddress;
  let daiContract: ERC20;

  // contracts
  let kyberV2Connector: KyberV2Connector;

  beforeEach(async () => {
    [owner, other] = await ethers.getSigners();

    daiContract = (await ethers.getContractAt(
      'contracts/dependencies/openzeppelin/contracts/IERC20.sol:IERC20',
      DAI_CONTRACT,
    )) as ERC20;

    daiContract = await daiContract.connect(await getSignerFromAddress('0xb527a981e1d415af696936b3174f2d7ac8d11369'));

    await daiContract.transfer(owner.address, DEFAULT_AMOUNT.mul(5));

    const kyberV2ConnectorFactory = await ethers.getContractFactory('KyberV2Connector');
    kyberV2Connector = await kyberV2ConnectorFactory.deploy();
    await kyberV2Connector.deployed();
  });

  it('Swap ETH to USDC', async () => {
    const swapAmount = ethers.utils.parseEther('10');

    const [calldata] = await kyberCalldata({
      toAddress: kyberV2Connector.address,
      fromToken: ETH_CONTRACT_2,
      toToken: DAI_CONTRACT,
      amount: swapAmount.toString(),
      slippage: 50,
    });

    await kyberV2Connector
      .connect(other)
      .swap(DAI_CONTRACT, ETH_CONTRACT_2, swapAmount, calldata as string, { value: swapAmount });

    expect(
      parseInt(ethers.utils.formatEther((await daiContract.callStatic.balanceOf(kyberV2Connector.address)).toString())),
    ).to.greaterThan(0);
  });

  it('Swap DAI to ETH', async () => {
    const swapAmount = ethers.utils.parseEther('1000');

    const [calldata] = await kyberCalldata({
      toAddress: kyberV2Connector.address,
      fromToken: DAI_CONTRACT,
      toToken: ETH_CONTRACT_2,
      amount: swapAmount.toString(),
      slippage: 50,
    });

    await daiContract.transfer(kyberV2Connector.address, swapAmount);

    await kyberV2Connector.connect(other).swap(ETH_CONTRACT_2, DAI_CONTRACT, swapAmount, calldata as string);

    expect(
      parseInt(ethers.utils.formatEther((await ethers.provider.getBalance(kyberV2Connector.address)).toString())),
    ).to.greaterThan(0);
  });
});
