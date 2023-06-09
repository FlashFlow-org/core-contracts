// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC20 } from '../../dependencies/openzeppelin/contracts/IERC20.sol';

import { IAaveV3Connector } from '../../interfaces/connectors/IAaveV3Connector.sol';
import { IPool } from '../../interfaces/external/aave-v3/IPool.sol';
import { IPoolDataProvider } from '../../interfaces/external/aave-v3/IPoolDataProvider.sol';
import { IPoolAddressesProvider } from '../../interfaces/external/aave-v3/IPoolAddressesProvider.sol';

import { UniversalERC20 } from '../../lib/UniversalERC20.sol';

contract AaveV3Connector is IAaveV3Connector {
    using UniversalERC20 for IERC20;

    /* ============ Constants ============ */

    /**
     * @dev Aave Pool Provider
     */
    IPoolAddressesProvider internal constant ADDRESSES_PROVIDER =
        IPoolAddressesProvider(0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb);

    /**
     * @dev Aave Pool Data Provider
     */
    IPoolDataProvider internal constant DATA_PROVIDER = IPoolDataProvider(0x69FA688f1Dc47d4B5d8029D5a35FB7a548310654);

    /**
     * @dev Aave Referral Code
     */
    uint16 internal constant REFERRAL_CODE = 0;

    /**
     * @dev Connector name
     */
    string public constant override NAME = 'AaveV3';

    /* ============ External Functions ============ */

    /**
     * @dev Deposit ETH/ERC20_Token.
     * @notice Deposit a token to Aave v3 for lending / collaterization.
     * @param _token The address of the token to deposit.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _amount The amount of the token to deposit. (For max: `type(uint).max`)
     */
    function deposit(address _token, uint256 _amount) external payable override {
        IPool aave = IPool(ADDRESSES_PROVIDER.getPool());

        IERC20 tokenC = IERC20(_token);

        _amount = _amount == type(uint256).max ? tokenC.balanceOf(address(this)) : _amount;

        tokenC.universalApprove(address(aave), _amount);
        aave.supply(_token, _amount, address(this), REFERRAL_CODE);

        if (!getisCollateral(_token)) {
            aave.setUserUseReserveAsCollateral(_token, true);
        }
    }

    /**
     * @dev Withdraw ETH/ERC20_Token.
     * @notice Withdraw deposited token from Aave v3
     * @param _token The address of the token to withdraw.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _amount The amount of the token to withdraw. (For max: `type(uint).max`)
     */
    function withdraw(address _token, uint256 _amount) external payable override {
        IPool aave = IPool(ADDRESSES_PROVIDER.getPool());

        IERC20 tokenC = IERC20(_token);

        uint256 initialBalance = tokenC.balanceOf(address(this));
        aave.withdraw(_token, _amount, address(this));
        uint256 finalBalance = tokenC.balanceOf(address(this));

        _amount = finalBalance - initialBalance;
    }

    /**
     * @dev Borrow ETH/ERC20_Token.
     * @notice Borrow a token using Aave v3
     * @param _token The address of the token to borrow.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _rateMode The type of debt. (For Stable: 1, Variable: 2)
     * @param _amount The amount of the token to borrow.
     */
    function borrow(address _token, uint256 _rateMode, uint256 _amount) external payable override {
        IPool aave = IPool(ADDRESSES_PROVIDER.getPool());

        aave.borrow(_token, _amount, _rateMode, REFERRAL_CODE, address(this));
    }

    /**
     * @dev Payback borrowed ETH/ERC20_Token.
     * @notice Payback debt owed.
     * @param _token The address of the token to payback.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _amount The amount of the token to payback. (For max: `type(uint).max`)
     * @param _rateMode The type of debt paying back. (For Stable: 1, Variable: 2)
     */
    function payback(address _token, uint256 _amount, uint256 _rateMode) external payable override {
        IPool aave = IPool(ADDRESSES_PROVIDER.getPool());

        IERC20 tokenC = IERC20(_token);

        _amount = _amount == type(uint256).max ? getPaybackBalance(_token, address(this), _rateMode) : _amount;

        tokenC.universalApprove(address(aave), _amount);
        aave.repay(_token, _amount, _rateMode, address(this));
    }

    /* ============ Public Functions ============ */

    /**
     * @dev Get total debt balance & fee for an asset
     * @param _token token address of the debt.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _recipeint Address whose balance we get.
     * @param _rateMode Borrow rate mode (Stable = 1, Variable = 2)
     */
    function getPaybackBalance(address _token, address _recipeint, uint256 _rateMode) public view returns (uint256) {
        (, uint256 stableDebt, uint256 variableDebt, , , , , , ) = DATA_PROVIDER.getUserReserveData(_token, _recipeint);
        return _rateMode == 1 ? stableDebt : variableDebt;
    }

    /**
     * @dev Get total collateral balance for an asset
     * @param _token token address of the collateral.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _recipeint Address whose balance we get.
     */
    function getCollateralBalance(address _token, address _recipeint) public view returns (uint256 balance) {
        (balance, , , , , , , , ) = DATA_PROVIDER.getUserReserveData(_token, _recipeint);
    }

    /* ============ Internal Functions ============ */

    /**
     * @dev Checks if collateral is enabled for an asset
     * @param _token token address of the asset.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     */
    function getisCollateral(address _token) internal view returns (bool isCollateral) {
        (, , , , , , , , isCollateral) = DATA_PROVIDER.getUserReserveData(_token, address(this));
    }
}
