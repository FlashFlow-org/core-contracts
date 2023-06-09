// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC20 } from '../dependencies/openzeppelin/contracts/IERC20.sol';

import { ICompoundV3Connector } from '../interfaces/connectors/ICompoundV3Connector.sol';
import { IComet } from '../interfaces/external/compound-v3/IComet.sol';

import { UniversalERC20 } from '../lib/UniversalERC20.sol';

contract CompoundV3Connector is ICompoundV3Connector {
    using UniversalERC20 for IERC20;

    /* ============ Constants ============ */

    /**
     * @dev Connector name
     */
    string public constant NAME = 'CompoundV3';

    /* ============ External Functions ============ */

    /**
     * @dev Deposit base asset or collateral asset supported by the _market.
     * @notice Deposit a token to Compound for lending / collaterization.
     * @param _market The address of the market.
     * @param _token The address of the token to be supplied. (For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _amount The amount of the token to deposit. (For max: `type(uint).max`)
     */
    function deposit(address _market, address _token, uint256 _amount) external payable override {
        require(_market != address(0) && _token != address(0), 'invalid market/token address');

        IERC20 tokenC = IERC20(_token);

        if (_token == getBaseToken(_market)) {
            require(IComet(_market).borrowBalanceOf(address(this)) == 0, 'debt not repaid');
        }

        _amount = _amount == type(uint).max ? tokenC.balanceOf(address(this)) : _amount;

        tokenC.universalApprove(_market, _amount);

        IComet(_market).supply(_token, _amount);
    }

    /**
     * @dev Withdraw base/collateral asset.
     * @notice Withdraw base token or deposited token from Compound.
     * @param _market The address of the market.
     * @param _token The address of the token to be withdrawn. (For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _amount The amount of the token to withdraw. (For max: `type(uint).max`)
     */
    function withdraw(address _market, address _token, uint256 _amount) external payable override {
        require(_market != address(0) && _token != address(0), 'invalid market/token address');

        uint256 initialBalance = _getAccountSupplyBalanceOfAsset(address(this), _market, _token);

        if (_token == getBaseToken(_market)) {
            if (_amount == type(uint).max) {
                _amount = initialBalance;
            } else {
                //if there are supplies, ensure withdrawn _amount
                // is not greater than supplied i.e can't borrow using withdraw.
                require(_amount <= initialBalance, 'withdraw-amount-greater-than-supplies');
            }

            //if borrow balance > 0, there are no supplies so no withdraw, borrow instead.
            require(IComet(_market).borrowBalanceOf(address(this)) == 0, 'withdraw-disabled-for-zero-supplies');
        } else {
            _amount = _amount == type(uint).max ? initialBalance : _amount;
        }

        IComet(_market).withdraw(_token, _amount);
    }

    /**
     * @dev Borrow base asset.
     * @notice Borrow base token from Compound.
     * @param _market The address of the market.
     * @param _token The address of the token to be borrowed. (For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _amount The amount of base token to borrow.
     */
    function borrow(address _market, address _token, uint256 _amount) external payable override {
        require(_market != address(0), 'invalid market address');
        require(_token == getBaseToken(_market), 'invalid token');
        require(IComet(_market).balanceOf(address(this)) == 0, 'borrow-disabled-when-supplied-base');

        IComet(_market).withdraw(_token, _amount);
    }

    /**
     * @dev Repays the borrowed base asset.
     * @notice Repays the borrow of the base asset.
     * @param _market The address of the market.
     * @param _token The address of the token to be repaid. (For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _amount The amount to be repaid.
     */
    function payback(address _market, address _token, uint256 _amount) external payable override {
        require(_market != address(0) && _token != address(0), 'invalid market/token address');
        require(_token == getBaseToken(_market), 'invalid token');

        IERC20 tokenC = IERC20(_token);

        uint256 initialBalance = IComet(_market).borrowBalanceOf(address(this));

        if (_amount == type(uint).max) {
            _amount = initialBalance;
        } else {
            require(_amount <= initialBalance, 'payback-amount-greater-than-borrows');
        }

        //if supply balance > 0, there are no borrowing so no repay, supply instead.
        require(IComet(_market).balanceOf(address(this)) == 0, 'cannot-repay-when-supplied');

        tokenC.universalApprove(_market, _amount);

        IComet(_market).supply(_token, _amount);
    }

    /* ============ Public Functions ============ */

    /**
     * @dev Get total debt balance & fee for an asset
     * @param _market Market contract address.
     * @param _recipient Address whose balance we get.
     */
    function borrowBalanceOf(address _market, address _recipient) public view override returns (uint256) {
        return IComet(_market).borrowBalanceOf(_recipient);
    }

    /**
     * @dev Get total collateral balance for an asset
     * @param _market Market contract address.
     * @param _token Token address of the collateral.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _recipient Address whose balance we get.
     */
    function collateralBalanceOf(
        address _market,
        address _recipient,
        address _token
    ) public view override returns (uint256) {
        return IComet(_market).collateralBalanceOf(_recipient, _token);
    }

    /* ============ Internal Functions ============ */

    /**
     * @dev Get base _token on the current _market
     * @param _market Market contract address.
     */
    function getBaseToken(address _market) internal view returns (address baseToken) {
        baseToken = IComet(_market).baseToken();
    }

    function _getAccountSupplyBalanceOfAsset(
        address account,
        address _market,
        address asset
    ) internal returns (uint256 balance) {
        if (asset == getBaseToken(_market)) {
            //balance in base
            balance = IComet(_market).balanceOf(account);
        } else {
            //balance in asset denomination
            balance = uint256(IComet(_market).userCollateral(account, asset).balance);
        }
    }
}
