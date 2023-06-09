// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { PoolAddress } from '../../dependencies/uniswap/libraries/PoolAddress.sol';

interface IUniswapFlashloan {
    struct FlashParams {
        PoolAddress.PoolKey poolKey;
        uint256 amount0;
        uint256 amount1;
    }

    function uniswapV3FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external;
}
