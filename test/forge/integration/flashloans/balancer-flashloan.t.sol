// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import 'forge-std/Test.sol';
import { IERC20 } from 'contracts/dependencies/openzeppelin/contracts/IERC20.sol';

import { IBaseFlashloan } from 'contracts/interfaces/IBaseFlashloan.sol';

import { BalancerFlashloan } from 'contracts/flashloan/BalancerFlashloan.sol';

contract TestBalancerFlashloan is Test {
    BalancerFlashloan public connector;

    address public wethC = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public wethWhale = 0x44Cc771fBE10DeA3836f37918cF89368589b6316;

    address public balancerLending = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    uint256 public amount = 1 ether;
    uint256 public fee = 0;
    address public token = wethC;

    function test_flashloan_balancer() public {
        connector.flashLoan(token, amount, bytes(''));
    }

    function test_receiveFlashLoan() public {
        bytes memory data = abi.encode(token, amount, address(this), bytes(''));

        vm.store(address(connector), bytes32(uint256(0)), bytes32(uint256(2)));
        vm.store(address(connector), bytes32(uint256(1)), bytes32(keccak256(data)));

        vm.prank(wethWhale);
        IERC20(token).transfer(address(connector), amount);

        address[] memory tokens = new address[](1);
        tokens[0] = token;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        uint256[] memory fees = new uint256[](1);
        fees[0] = fee;

        vm.prank(balancerLending);
        connector.receiveFlashLoan(tokens, amounts, fees, data);
    }

    function test_receiveFlashLoan_NotBalancerSender() public {
        bytes memory data = abi.encode(token, amount, address(this), bytes(''));

        vm.store(address(connector), bytes32(uint256(0)), bytes32(uint256(2)));
        vm.store(address(connector), bytes32(uint256(1)), bytes32(keccak256(data)));

        vm.prank(wethWhale);
        IERC20(token).transfer(address(connector), amount);

        address[] memory tokens = new address[](1);
        tokens[0] = token;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        uint256[] memory fees = new uint256[](1);
        fees[0] = fee;

        vm.expectRevert(abi.encodePacked('not balancer sender'));
        connector.receiveFlashLoan(tokens, amounts, fees, data);
    }

    function executeOperation(
        address _token,
        uint256 _amount,
        uint256 /* _fee */,
        address _initiator,
        string memory /* _targetName */,
        bytes calldata /* _params */
    ) external returns (bool) {
        assertEq(_initiator, address(this));

        assertEq(_amount, IERC20(_token).balanceOf(address(this)));

        IERC20(_token).transfer(address(connector), _amount);

        return true;
    }

    receive() external payable {}

    function setUp() public {
        string memory url = vm.rpcUrl('mainnet');
        uint256 forkId = vm.createFork(url);
        vm.selectFork(forkId);

        connector = new BalancerFlashloan(balancerLending);
    }
}
