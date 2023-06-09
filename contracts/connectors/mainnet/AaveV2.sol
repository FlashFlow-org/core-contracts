// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC20 } from '../../dependencies/openzeppelin/contracts/IERC20.sol';

import { IAaveV2Connector } from '../../interfaces/connectors/IAaveV2Connector.sol';
import { ILendingPool } from '../../interfaces/external/aave-v2/ILendingPool.sol';
import { IProtocolDataProvider } from '../../interfaces/external/aave-v2/IProtocolDataProvider.sol';
import { ILendingPoolAddressesProvider } from '../../interfaces/external/aave-v2/ILendingPoolAddressesProvider.sol';

import { UniversalERC20 } from '../../lib/UniversalERC20.sol';

contract AaveV2Connector is IAaveV2Connector {
    using UniversalERC20 for IERC20;

    /* ============ Constants ============ */

    /**
     * @dev Aave Lending Pool Provider
     */
    ILendingPoolAddressesProvider internal constant ADDRESSES_PROVIDER =
        ILendingPoolAddressesProvider(0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5);

    /**
     * @dev Aave Protocol Data Provider
     */
    IProtocolDataProvider internal constant DATA_PROVIDER =
        IProtocolDataProvider(0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d);

    /**
     * @dev Aave Referral Code
     */
    uint16 internal constant REFERRAL_CODE = 0;

    /**
     * @dev Connector name
     */
    string public constant override NAME = 'AaveV2';

    /* ============ External Functions ============ */

    /**
     * @dev Deposit ETH/ERC20_Token.
     * @notice Deposit a token to Aave v2 for lending / collaterization.
     * @param _token The address of the token to deposit.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _amount The amount of the token to deposit. (For max: `type(uint).max`)
     */
    function deposit(address _token, uint256 _amount) external payable override {
        ILendingPool aave = ILendingPool(ADDRESSES_PROVIDER.getLendingPool());

        IERC20 tokenC = IERC20(_token);

        _amount = _amount == type(uint).max ? tokenC.balanceOf(address(this)) : _amount;

        tokenC.universalApprove(address(aave), _amount);

        aave.deposit(_token, _amount, address(this), REFERRAL_CODE);

        if (!getIsCollateral(_token)) {
            aave.setUserUseReserveAsCollateral(_token, true);
        }
    }

    /**
     * @dev Withdraw ETH/ERC20_Token.
     * @notice Withdraw deposited token from Aave v2
     * @param _token The address of the token to withdraw.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _amount The amount of the token to withdraw. (For max: `type(uint).max`)
     */
    function withdraw(address _token, uint256 _amount) external payable override {
        ILendingPool aave = ILendingPool(ADDRESSES_PROVIDER.getLendingPool());
        IERC20 tokenC = IERC20(_token);

        uint256 initialBal = tokenC.balanceOf(address(this));
        aave.withdraw(_token, _amount, address(this));
        uint256 finalBal = tokenC.balanceOf(address(this));

        _amount = finalBal - initialBal;
    }

    /**
     * @dev Borrow ETH/ERC20_Token.
     * @notice Borrow a token using Aave v2
     * @param _token The address of the token to borrow.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _rateMode The type of borrow debt. (For Stable: 1, Variable: 2)
     * @param _amount The amount of the token to borrow.
     */
    function borrow(address _token, uint256 _rateMode, uint256 _amount) external payable override {
        ILendingPool aave = ILendingPool(ADDRESSES_PROVIDER.getLendingPool());

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
        ILendingPool aave = ILendingPool(ADDRESSES_PROVIDER.getLendingPool());

        IERC20 tokenC = IERC20(_token);

        if (_amount == type(uint).max) {
            uint256 balance = tokenC.balanceOf(address(this));
            uint256 amountDebt = getPaybackBalance(_token, _rateMode, address(this));
            _amount = balance <= amountDebt ? balance : amountDebt;
        }

        tokenC.universalApprove(address(aave), _amount);

        aave.repay(_token, _amount, _rateMode, address(this));
    }

    /* ============ Public Functions ============ */

    /**
     * @dev Get total debt balance & fee for an asset
     * @param _token token address of the debt.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _rateMode Borrow rate mode (Stable = 1, Variable = 2)
     * @param _user Address whose balance we get.
     */
    function getPaybackBalance(address _token, uint _rateMode, address _user) public view override returns (uint) {
        (, uint stableDebt, uint variableDebt, , , , , , ) = DATA_PROVIDER.getUserReserveData(_token, _user);
        return _rateMode == 1 ? stableDebt : variableDebt;
    }

    /**
     * @dev Get total collateral balance for an asset
     * @param _token token address of the collateral.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     * @param _user Address whose balance we get.
     */
    function getCollateralBalance(address _token, address _user) public view override returns (uint256 balance) {
        (balance, , , , , , , , ) = DATA_PROVIDER.getUserReserveData(_token, _user);
    }

    /* ============ Internal Functions ============ */

    /**
     * @dev Checks if collateral is enabled for an asset
     * @param _token token address of the asset.(For ETH: 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
     */
    function getIsCollateral(address _token) internal view returns (bool IsCollateral) {
        (, , , , , , , , IsCollateral) = DATA_PROVIDER.getUserReserveData(_token, address(this));
    }
}
