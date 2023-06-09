// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import 'forge-std/Test.sol';
import { IERC20 } from 'contracts/dependencies/openzeppelin/contracts/IERC20.sol';

import { IBaseFlashloan } from 'contracts/interfaces/IBaseFlashloan.sol';

import { MakerFlashloan } from 'contracts/flashloan/MakerFlashloan.sol';

contract TestMakerFlashloan is Test {
    MakerFlashloan public connector;

    address public daiC = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public daiWhale = 0xb527a981e1d415AF696936B3174f2d7aC8D11369;

    address public daiToken = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address public makerLending = 0x1EB4CF3A948E7D72A198fe073cCb8C7a948cD853;

    uint256 public amount = 1000 ether;
    address public token = daiC;

    function test_flashloan_MakerTryCatch() public {
        // maker disable flashloan
        try connector.flashLoan(token, amount, bytes('')) {} catch {}
    }

    function test_onFlashLoan() public {
        bytes memory data = abi.encode(token, amount, address(this), bytes(''));

        vm.store(address(connector), bytes32(uint256(0)), bytes32(uint256(2)));
        vm.store(address(connector), bytes32(uint256(1)), bytes32(keccak256(data)));

        vm.prank(daiC);
        IERC20(token).transfer(address(connector), amount);

        vm.prank(makerLending);
        connector.onFlashLoan(address(connector), address(0), type(uint256).max, type(uint256).max, data);
    }

    function test_onFlashLoan_NotSameSender() public {
        bytes memory data = abi.encode(token, amount, address(this), bytes(''));

        vm.store(address(connector), bytes32(uint256(0)), bytes32(uint256(2)));
        vm.store(address(connector), bytes32(uint256(1)), bytes32(keccak256(data)));

        vm.prank(daiC);
        IERC20(token).transfer(address(connector), amount);

        vm.expectRevert(abi.encodePacked('not same sender'));
        vm.prank(makerLending);
        connector.onFlashLoan(address(msg.sender), address(0), type(uint256).max, type(uint256).max, data);
    }

    function test_onFlashLoan_NotMakerSender() public {
        bytes memory data = abi.encode(token, amount, address(this), bytes(''));

        vm.store(address(connector), bytes32(uint256(0)), bytes32(uint256(2)));
        vm.store(address(connector), bytes32(uint256(1)), bytes32(keccak256(data)));

        vm.prank(daiC);
        IERC20(token).transfer(address(connector), amount);

        vm.expectRevert(abi.encodePacked('not maker sender'));
        connector.onFlashLoan(address(connector), address(0), type(uint256).max, type(uint256).max, data);
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

        connector = new MakerFlashloan(makerLending, daiToken);
    }
}
