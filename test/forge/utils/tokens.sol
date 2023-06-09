// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Test } from 'forge-std/Test.sol';
import { Script } from 'forge-std/Script.sol';

contract Tokens is Test, Script {
    function getToken(string memory _name) public view returns (address) {
        uint256 chainId = getChainID();

        if (chainId == 1) {
            if (compare(_name, 'dai')) {
                return 0x6B175474E89094C44Da98b954EedeAC495271d0F;
            } else if (compare(_name, 'usdc')) {
                return 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
            } else if (compare(_name, 'eth')) {
                return 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
            } else if (compare(_name, 'weth')) {
                return 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
            } else if (compare(_name, 'usdt')) {
                return 0xdAC17F958D2ee523a2206206994597C13D831ec7;
            }
        } else if (chainId == 137) {
            if (compare(_name, 'dai')) {
                return 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
            } else if (compare(_name, 'usdc')) {
                return 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
            } else if (compare(_name, 'matic')) {
                return 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
            } else if (compare(_name, 'weth')) {
                return 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
            } else if (compare(_name, 'usdt')) {
                return 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
            }
        } else if (chainId == 56) {
            if (compare(_name, 'dai')) {
                return 0x1AF3F329e8BE154074D8769D1FFa4eE058B1DBc3;
            } else if (compare(_name, 'usdc')) {
                return 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
            } else if (compare(_name, 'bnb')) {
                return 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
            } else if (compare(_name, 'usdt')) {
                return 0x55d398326f99059fF775485246999027B3197955;
            } else if (compare(_name, 'wbnb')) {
                return 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
            } else if (compare(_name, 'busd')) {
                return 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
            }
        }
        revert('dont have token');
    }

    function compare(string memory str1, string memory str2) public pure returns (bool) {
        if (bytes(str1).length != bytes(str2).length) {
            return false;
        }
        return keccak256(abi.encodePacked(str1)) == keccak256(abi.encodePacked(str2));
    }

    function getChainID() public view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }
}
