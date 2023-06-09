// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { Test } from 'forge-std/Test.sol';
import { ERC20 } from 'contracts/dependencies/openzeppelin/contracts/ERC20.sol';

contract TestGasStruct is Test {
    struct Position1 {
        address token;
        address account;
        uint256 amount;
    }

    mapping(address => uint256) public positionsIndex;
    mapping(bytes32 => Position1) public positions;
    mapping(address => address) public accounts;

    function test_gasStruct() public {
        Position1 memory testStruct = Position1(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, msg.sender, 1000 ether);

        updateStruct(testStruct);
    }

    function test_gasStruct_Optimize() public {
        Position1 memory testStruct = Position1(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, msg.sender, 1000 ether);

        updateStructOptimize(testStruct);
    }

    function updateStruct(Position1 memory _position) public {
        require(_position.account == msg.sender, 'not a owner');

        uint256 index = positionsIndex[_position.account] += 1;
        positionsIndex[_position.account] = index;

        accounts[_position.account] = address(this);
        positions[bytes32(abi.encodePacked(_position.account, index))] = _position;
    }

    function updateStructOptimize(Position1 memory _position) public {
        address account = _position.account;

        require(account == msg.sender, 'not a owner');

        uint256 index = positionsIndex[account] += 1;
        positionsIndex[account] = index;

        accounts[account] = address(this);
        positions[bytes32(abi.encodePacked(account, index))] = _position;
    }

    receive() external payable {}

    function setUp() public {}
}
