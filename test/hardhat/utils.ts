/* global ethers, network */
import { ethers, network } from 'hardhat';
import { BigNumber, providers } from 'ethers';
import axios from 'axios';
import { AlphaRouter, SwapType } from '@uniswap/smart-order-router';
import { CurrencyAmount, Percent, Token, TradeType } from '@uniswap/sdk-core';
import { Protocol } from '@uniswap/router-sdk';

export async function setTime(timestamp: number) {
  await ethers.provider.send('evm_setNextBlockTimestamp', [timestamp]);
}

export async function takeSnapshot() {
  return ethers.provider.send('evm_snapshot', []);
}

export async function revertSnapshot(id: string) {
  return ethers.provider.send('evm_revert', [id]);
}

export async function advanceTime(sec: number) {
  const now = (await ethers.provider.getBlock('latest')).timestamp;
  await setTime(now + sec);
}

// export async function getSignerFromAddress(address: string) {
//   const provider = new providers.JsonRpcProvider('https://hardhat.ztake.org/havilov/');
//
//   await provider.send("hardhat_impersonateAccount", [address]);
//
//   return provider.getUncheckedSigner(address);
// }

export async function getSignerFromAddress(address: string) {
  await network.provider.request({
    method: 'hardhat_impersonateAccount',
    params: [address],
  });

  return ethers.provider.getSigner(address);
}

export async function inchCalldata({
  fromAddress,
  fromToken,
  toToken,
  amount,
  slippage,
}: {
  fromAddress: string;
  fromToken: string;
  toToken: string;
  amount: string;
  slippage: number;
}) {
  const ETH_CONTRACT_E = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';
  const ETH_CONTRACT = '0x0000000000000000000000000000000000000000';

  fromToken = fromToken === ETH_CONTRACT ? ETH_CONTRACT_E : fromToken;
  toToken = toToken === ETH_CONTRACT ? ETH_CONTRACT_E : toToken;

  const call = `https://api.1inch.exchange/v5.0/1/swap?fromTokenAddress=${fromToken}&toTokenAddress=${toToken}&amount=${amount}&fromAddress=${fromAddress}&slippage=${slippage}&disableEstimate=true`;
  console.log('call', call);

  const { data: resp } = await axios.get<{ tx: { data: string; value: string }; toTokenAmount: number }>(call);

  return [resp.tx.data, resp.toTokenAmount];
}

export async function kyberCalldata({
  fromToken,
  toToken,
  toAddress,
  amount,
  slippage,
}: {
  toAddress: string;
  fromToken: string;
  toToken: string;
  amount: string;
  slippage: number;
}) {
  const ETH_CONTRACT_E = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';
  const ETH_CONTRACT = '0x0000000000000000000000000000000000000000';

  fromToken = fromToken === ETH_CONTRACT ? ETH_CONTRACT_E : fromToken;
  toToken = toToken === ETH_CONTRACT ? ETH_CONTRACT_E : toToken;

  const call = `https://aggregator-api.kyberswap.com/ethereum/route/encode?tokenIn=${fromToken}&tokenOut=${toToken}&amountIn=${amount}&to=${toAddress}&slippageTolerance=${slippage}`;
  console.log('call', call);

  const { data: resp } = await axios.get<{ encodedSwapData: string; outputAmount: string }>(call);

  return [resp.encodedSwapData, resp.outputAmount];
}

const provider = new ethers.providers.JsonRpcProvider(
  'https://mainnet.infura.io/v3/8f786b96d16046b78e0287fa61c6fcf8',
  1,
);

// @ts-ignore
const router = new AlphaRouter({ provider, chainId: 1 });

export async function uniSwap(amount: string, fromToken: string, toToken: string, recipient: string) {
  const WETH_CONTRACT = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
  const ETH_CONTRACT = '0x0000000000000000000000000000000000000000'.toLowerCase();
  const ETH_CONTRACT_2 = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'.toLowerCase();

  const fromAddress =
    fromToken.toLowerCase() === ETH_CONTRACT || fromToken.toLowerCase() === ETH_CONTRACT_2 ? WETH_CONTRACT : fromToken;
  const fromDecimals = await (await ethers.getContractAt('ERC20', fromAddress)).decimals();

  const FROM_TOKEN = new Token(1, fromAddress, fromDecimals);

  const toAddress =
    toToken.toLowerCase() === ETH_CONTRACT || toToken.toLowerCase() === ETH_CONTRACT_2 ? WETH_CONTRACT : toToken;
  const toDecimals = await (await ethers.getContractAt('ERC20', toAddress)).decimals();

  const TO_TOKEN = new Token(1, toAddress, toDecimals);

  return router.route(
    CurrencyAmount.fromRawAmount(FROM_TOKEN, amount),
    TO_TOKEN,
    TradeType.EXACT_INPUT,
    {
      type: SwapType.SWAP_ROUTER_02,
      recipient,
      deadline: Date.now() + 3600 * 10,
      slippageTolerance: new Percent(50),
    },
    {
      protocols: [Protocol.V2, Protocol.V3],
    },
  );
}

export function openCalldata(
  sig: string,
  _targets: string[],
  _datas: string[],
  _customDatas: string[],
  _origin: string,
) {
  const encoder = new ethers.utils.AbiCoder();

  return encoder.encode(
    ['bytes4', 'address[]', 'bytes[]', 'bytes[]', 'address'],
    [sig, _targets, _datas, _customDatas, _origin],
  );
}

export function closeCalldata(
  sig: string,
  collateral: string,
  debt: string,
  owner: string,
  amount: BigNumber,
  calldata: string,
) {
  const encoder = new ethers.utils.AbiCoder();

  const closeCallback = encoder.encode(
    ['bytes4', 'address', 'address', 'address', 'uint256', 'bytes'],
    [sig, collateral, debt, owner, amount.toHexString(), calldata],
  );

  return encoder.encode(
    ['address[]', 'uint256[]', 'uint256[]', 'uint16', 'bytes'],
    [[debt], [amount.toHexString()], [0], 0, closeCallback],
  );
}
