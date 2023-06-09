// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC20 } from '../dependencies/openzeppelin/contracts/IERC20.sol';

import { IBaseFlashloan } from '../interfaces/IBaseFlashloan.sol';

import { UniversalERC20 } from '../lib/UniversalERC20.sol';

abstract contract BaseFlashloan is IBaseFlashloan {
    using UniversalERC20 for IERC20;

    /* ============ State Variables ============ */

    // Has state 1 on the enter flashlaon and state 2 on the callback
    uint256 internal _status;

    // The hash of the date that is sent to the flashloan as an additional calldata
    bytes32 internal _dataHash;

    /* ============ Modifiers ============ */

    /**
     * @dev  better checking by double encoding the data.
     * @notice better checking by double encoding the data.
     * @param data_ data passed.
     */
    modifier verifyDataHash(bytes memory data_) {
        bytes32 dataHash_ = keccak256(data_);
        require(dataHash_ == _dataHash && dataHash_ != bytes32(0), 'invalid-data-hash');
        require(_status == 2, 'already-entered');
        _dataHash = bytes32(0);
        _;
        _status = 1;
    }

    /**
     * @dev reentrancy gaurd.
     * @notice reentrancy gaurd.
     */
    modifier reentrancy() {
        require(_status == 1, 'already-entered');
        _status = 2;
        _;
        require(_status == 1, 'already-entered');
    }

    /* ============ Constructor ============ */

    /**
     * @dev Constructor.
     * @notice Sets the status to the default value
     */
    constructor() {
        require(_status == 0, 'cannot call again');
        _status = 1;
    }

    /* ============ External Functions ============ */

    /* ============ Public Functions ============ */

    /* ============ Internal Functions ============ */

    /**
     * @dev Approves the tokens to the receiver address with allowance (amount + fee).
     * @notice Approves the tokens to the receiver address with allowance (amount + fee).
     * @param _token token address for the respective tokens.
     * @param _amount balance for the respective tokens.
     * @param _receiver address to which tokens have to be approved.
     */
    function safeApprove(address _token, uint256 _amount, address _receiver) internal {
        IERC20(_token).universalApprove(_receiver, _amount);
    }

    /**
     * @dev Transfers the tokens to the receiver address (amount + fee).
     * @notice Transfers the tokens to the receiver address (amount + fee).
     * @param _token token address to calculate balance for.
     * @param _amount balance for the respective tokens.
     * @param _receiver address to which tokens have to be transferred.
     */
    function safeTransfer(address _token, uint256 _amount, address _receiver) internal {
        IERC20(_token).universalTransfer(_receiver, _amount);
    }

    /**
     * @dev Calculates the balances.
     * @notice Calculates the balances of the account passed for the tokens.
     * @param _token token address to calculate balance for.
     */
    function getBalance(address _token) internal view returns (uint256) {
        return IERC20(_token).universalBalanceOf(address(this));
    }

    /**
     * @dev Calculate fees for the respective amounts and fee in BPS passed.
     * @notice Calculate fees for the respective amounts and fee in BPS passed. 1 BPS == 0.01%.
     * @param _amount list of amounts.
     * @param _bps fee in BPS.
     */
    function calculateFee(uint256 _amount, uint256 _bps) internal pure returns (uint256) {
        return (_amount * _bps) / (10 ** 4);
    }
}
