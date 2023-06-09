// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title PercentageMath library
 * @author FlashFlow
 * @notice Provides functions to perform percentage calculations
 * @dev Percentages are defined by default with 2 decimals of precision (100.00). The precision is indicated by PERCENTAGE_FACTOR
 */
library PercentageMath {
    // Maximum percentage factor (100.00%)
    uint256 internal constant PERCENTAGE_FACTOR = 1e4;

    function mulTo(uint256 _x, uint256 _y) internal pure returns (uint256 amount) {
        amount = (_x * _y) / PERCENTAGE_FACTOR;
    }
}
