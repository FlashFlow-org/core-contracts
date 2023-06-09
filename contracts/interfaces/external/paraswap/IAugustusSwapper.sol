//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IAugustusSwapper {
    function getTokenTransferProxy() external view returns (address);
}
