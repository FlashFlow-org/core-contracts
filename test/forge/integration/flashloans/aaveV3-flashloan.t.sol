// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import 'forge-std/Test.sol';
import { IERC20 } from 'contracts/dependencies/openzeppelin/contracts/IERC20.sol';

import { IBaseFlashloan } from 'contracts/interfaces/IBaseFlashloan.sol';

import { AaveV3Flashloan } from 'contracts/flashloan/AaveV3Flashloan.sol';

contract TestAaveV3Flashloan is Test {
    AaveV3Flashloan public connector;

    address public daiC = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public daiWhale = 0xb527a981e1d415AF696936B3174f2d7aC8D11369;

    address public aaveLending = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address public aaveData = 0x7B4EB56E7CD4b454BA8ff71E4518426369a138a3;

    uint256 public amount = 1000 ether;
    address public token = daiC;
    uint256 public fee = 900000000000000000;

    function test_flashloan() public {
        connector.flashLoan(token, amount, bytes(''));
    }

    function test_executeOperation() public {
        bytes memory data = abi.encode(address(this), bytes('Hello'));

        vm.store(address(connector), bytes32(uint256(0)), bytes32(uint256(2)));
        vm.store(address(connector), bytes32(uint256(1)), bytes32(keccak256(data)));

        vm.prank(daiC);
        IERC20(token).transfer(address(connector), amount);

        vm.prank(aaveLending);
        connector.executeOperation(token, amount, fee, address(connector), data);
    }

    function test_executeOperation_NotSameSender() public {
        bytes memory data = abi.encode(address(this), bytes('Hello'));

        vm.store(address(connector), bytes32(uint256(0)), bytes32(uint256(2)));
        vm.store(address(connector), bytes32(uint256(1)), bytes32(keccak256(data)));

        vm.prank(daiC);
        IERC20(token).transfer(address(connector), amount);

        vm.expectRevert(abi.encodePacked('not same sender'));
        vm.prank(aaveLending);
        connector.executeOperation(token, amount, fee, msg.sender, data);
    }

    function test_executeOperation_NotAaveSender() public {
        bytes memory data = abi.encode(address(this), bytes('Hello'));

        vm.store(address(connector), bytes32(uint256(0)), bytes32(uint256(2)));
        vm.store(address(connector), bytes32(uint256(1)), bytes32(keccak256(data)));

        vm.prank(daiC);
        IERC20(token).transfer(address(connector), amount);

        vm.expectRevert(abi.encodePacked('not aave sender'));
        connector.executeOperation(token, amount, fee, address(connector), data);
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
            vm.prank(daiC);
            IERC20(daiC).transfer(address(this), _fee);

            IERC20(_token).transfer(address(connector), _amount + _fee);
        } else {
            IERC20(_token).transfer(address(connector), _amount);
        }

        return true;
    }

    receive() external payable {}

    function setUp() public {
        string memory url = vm.rpcUrl('mainnet');
        uint256 forkId = vm.createFork(url);
        vm.selectFork(forkId);

        connector = new AaveV3Flashloan(aaveLending, aaveData);
    }
}
