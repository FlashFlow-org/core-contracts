import fs from 'fs';
import '@nomiclabs/hardhat-waffle';
import '@typechain/hardhat';
import '@nomiclabs/hardhat-etherscan';
import 'hardhat-deploy';
import 'hardhat-tracer';
import 'hardhat-gas-reporter';
import 'hardhat-preprocessor';
import 'solidity-coverage';
import { config as dotEnvConfig } from 'dotenv';

function getRemappings() {
  return fs
    .readFileSync('remappings.txt', 'utf8')
    .split('\n')
    .filter(Boolean)
    .map(line => line.trim().split('='));
}

dotEnvConfig();

const { PRIVATE_KEY, ETHERSCAN_API_KEY } = process.env;

const config = {
  solidity: {
    version: '0.8.17',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  paths: {
    sources: './contracts', // Use ./src rather than ./contracts as Hardhat expects
    cache: './cache_hardhat', // Use a different cache for Hardhat than Foundry
  },
  networks: {
    gnosis: {
      url: `https://rpc.gnosis.gateway.fm`,
      accounts: PRIVATE_KEY
        ? [PRIVATE_KEY]
        : {
            mnemonic: 'test test test test test test test test test test test junk',
          },
    },
    bsc: {
      url: 'https://bsc-dataseed.binance.org/',
      accounts: [PRIVATE_KEY]
    },
    goerli: {
      url: `https://goerli.infura.io/v3/`,
      accounts: PRIVATE_KEY
        ? [PRIVATE_KEY]
        : {
            mnemonic: 'test test test test test test test test test test test junk',
          },
    },
    polygon: {
      url: `https://polygon-node-mgx.margex.ch`,
      accounts: PRIVATE_KEY
        ? [PRIVATE_KEY]
        : {
            mnemonic: 'test test test test test test test test test test test junk',
          },
    },
    mainnet: {
      url: `https://geth-node-mgx.margex.ch`,
      accounts: PRIVATE_KEY
        ? [PRIVATE_KEY]
        : {
            mnemonic: 'test test test test test test test test test test test junk',
          },
    },
    hardhat: {
      blockGasLimit: 9500000,
      chainId: 56,
      forking: {
        url: `https://bsc-mainnet.nodereal.io/v1/64a9df0874fb4a93b9d0a3849de012d3`,
        blockNumber: 28718507,
      },
      initialBaseFeePerGas: 5,
    },
    coverage: {
      url: 'http://127.0.0.1:8555',
    },
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY,
  },
  mocha: {
    timeout: 100000000,
  },
  // This fully resolves paths for imports in the ./lib directory for Hardhat
  preprocess: {
    eachLine: () => ({
      transform: (line: string) => {
        if (line.match(/^\s*import /i)) {
          getRemappings().forEach(([find, replace]) => {
            if (line.match(find)) {
              line = line.replace(find, replace);
            }
          });
        }
        return line;
      },
    }),
  },
};

export default config;
