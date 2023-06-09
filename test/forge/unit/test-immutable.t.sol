// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import 'forge-std/Test.sol';
import { ERC20 } from 'contracts/dependencies/openzeppelin/contracts/ERC20.sol';

contract Base is Test {
    address public immutable addr;

    constructor(address _addr) {
        addr = _addr;
    }

    function getAddr() public view returns (address) {
        return addr;
    }
}

contract InheritBase is Base {
    constructor() Base(0x444444Cc7FE267251797d8592C3f4d5EE6888D62) {}
}

contract Caller is Test {
    InheritBase inheritBase;

    function test_Immutable_call() public {
        (, bytes memory data) = address(inheritBase).call(abi.encodeWithSelector(inheritBase.getAddr.selector));

        address addr = abi.decode(data, (address));
        assertEq(addr, 0x444444Cc7FE267251797d8592C3f4d5EE6888D62);
    }

    function test_Immutable_delegatecall() public {
        (, bytes memory data) = address(inheritBase).delegatecall(abi.encodeWithSelector(inheritBase.getAddr.selector));

        address addr = abi.decode(data, (address));

        assertEq(addr, 0x444444Cc7FE267251797d8592C3f4d5EE6888D62);
    }

    receive() external payable {}

    function setUp() public {
        inheritBase = new InheritBase();
    }
}
