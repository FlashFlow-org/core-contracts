// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Test } from 'forge-std/Test.sol';
import { Script } from 'forge-std/Script.sol';
import { IERC20 } from 'contracts/dependencies/openzeppelin/contracts/IERC20.sol';
import { PoolAddress } from 'contracts/dependencies/uniswap/libraries/PoolAddress.sol';

import { IBaseFlashloan } from 'contracts/interfaces/IBaseFlashloan.sol';
import { IUniswapFlashloan } from 'contracts/interfaces/connectors/IUniswapFlashloan.sol';

import { UniswapFlashloan } from 'contracts/flashloan/UniswapFlashloan.sol';

contract TestUniswapFlashloan is Test, Script {
    UniswapFlashloan public connector;

    uint24 public fee = 3000;
    address public token0 = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // busd
    address public token1 = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56; // wbnb
    address public uniswapFactory = 0xdB1d10011AD0Ff90774D0C6Bb92e5C5c8b4461F7;

    address public pool = 0x32776Ed4D96ED069a2d812773F0AD8aD9Ef83CF8;
    address public weth = 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f;

    uint256 public amount0 = 1000 ether;
    uint256 public amount1 = 0;

    uint256 public fee0 = (amount0 * fee) / 1e6;

    function test_flashloan() public {
        IUniswapFlashloan.FlashParams memory params = IUniswapFlashloan.FlashParams(
            PoolAddress.PoolKey(token0, token1, fee),
            amount0,
            amount1
        );

        bytes memory data = abi.encode(params, bytes(''));

        connector.flashLoan(address(0), 0, data);
    }

    function test_uniswapV3FlashCallback_NotPool() public {
        bytes memory data = abi.encode(
            msg.sender,
            IUniswapFlashloan.FlashParams(PoolAddress.PoolKey(token0, token1, fee), amount0, amount1),
            bytes('')
        );

        vm.store(address(connector), bytes32(uint256(0)), bytes32(uint256(2)));
        vm.store(address(connector), bytes32(uint256(1)), bytes32(keccak256(data)));

        vm.prank(token0);
        IERC20(token0).transfer(address(connector), amount0 + fee0);

        vm.expectRevert(abi.encodePacked(''));
        connector.uniswapV3FlashCallback(fee0, 0, data);
    }

    function executeOperation(
        address _token,
        uint256 _amount,
        uint256 _fee,
        address _initiator,
        string memory /* _targetName */,
        bytes calldata /* _params */
    ) external returns (bool) {
        assertEq(_initiator, address(this));

        assertEq(_amount, IERC20(_token).balanceOf(address(this)));

        if (_fee > 0) {
            vm.prank(token0);
            IERC20(token0).transfer(address(this), _fee);

            IERC20(_token).transfer(address(connector), _amount + _fee);
        } else {
            IERC20(_token).transfer(address(connector), _amount);
        }

        return true;
    }

    receive() external payable {}

    function setUp() public {
        string memory url = vm.rpcUrl('bsc');
        uint256 forkId = vm.createFork(url);
        vm.selectFork(forkId);

        connector = new UniswapFlashloan(uniswapFactory, weth);
    }
}
