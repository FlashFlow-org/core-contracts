// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title Compound's Comet Ext Interface
 * @notice An efficient monolithic money market protocol
 * @author Compound
 */
interface ICometExtInterface {
    struct UserCollateral {
        uint128 balance;
        uint128 _reserved;
    }

    function allow(address manager, bool isAllowed) external;

    function allowBySig(
        address owner,
        address manager,
        bool isAllowed,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function collateralBalanceOf(address account, address asset) external view returns (uint128);

    function baseTrackingAccrued(address account) external view returns (uint64);

    function baseAccrualScale() external view returns (uint64);

    function baseIndexScale() external view returns (uint64);

    function factorScale() external view returns (uint64);

    function priceScale() external view returns (uint64);

    function maxAssets() external view returns (uint8);

    // function totalsBasic() external view  returns (TotalsBasic memory);

    function version() external view returns (string memory);

    /**
     * ===== ERC20 interfaces =====
     * Does not include the following functions/events, which are defined in `CometMainInterface` instead:
     * - function decimals()  external view returns (uint8)
     * - function totalSupply()  external view returns (uint256)
     * - function transfer(address dst, uint amount)  external returns (bool)
     * - function transferFrom(address src, address dst, uint amount)  external returns (bool)
     * - function balanceOf(address owner)  external view returns (uint256)
     * - event Transfer(address indexed from, address indexed to, uint256 amount)
     */
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    /**
     * @notice Approve `spender` to transfer up to `amount` from `src`
     * @dev This will overwrite the approval amount for `spender`
     *  and is subject to issues noted [here](https://eips.ethereum.org/EIPS/eip-20#approve)
     * @param spender The address of the account which may transfer tokens
     * @param amount The number of tokens that are approved (-1 means infinite)
     * @return Whether or not the approval succeeded
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @notice Get the current allowance from `owner` for `spender`
     * @param owner The address of the account which owns the tokens to be spent
     * @param spender The address of the account which may transfer tokens
     * @return The number of tokens allowed to be spent (-1 means infinite)
     */
    function allowance(address owner, address spender) external view returns (uint256);
}

/**
 * @title Compound's Comet Main Interface (without Ext)
 * @notice An efficient monolithic money market protocol
 * @author Compound
 */
interface IComet is ICometExtInterface {
    function supply(address asset, uint amount) external;

    function supplyTo(address dst, address asset, uint amount) external;

    function supplyFrom(address from, address dst, address asset, uint amount) external;

    function transfer(address dst, uint amount) external returns (bool);

    function transferFrom(address src, address dst, uint amount) external returns (bool);

    function transferAsset(address dst, address asset, uint amount) external;

    function transferAssetFrom(address src, address dst, address asset, uint amount) external;

    function withdraw(address asset, uint amount) external;

    function withdrawTo(address to, address asset, uint amount) external;

    function withdrawFrom(address src, address to, address asset, uint amount) external;

    function approveThis(address manager, address asset, uint amount) external;

    function withdrawReserves(address to, uint amount) external;

    function absorb(address absorber, address[] calldata accounts) external;

    function buyCollateral(address asset, uint minAmount, uint baseAmount, address recipient) external;

    function quoteCollateral(address asset, uint baseAmount) external view returns (uint);

    function getCollateralReserves(address asset) external view returns (uint);

    function getReserves() external view returns (int);

    function getPrice(address priceFeed) external view returns (uint);

    function isBorrowCollateralized(address account) external view returns (bool);

    function isLiquidatable(address account) external view returns (bool);

    function totalSupply() external view returns (uint256);

    function totalBorrow() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function borrowBalanceOf(address account) external view returns (uint256);

    function pause(
        bool supplyPaused,
        bool transferPaused,
        bool withdrawPaused,
        bool absorbPaused,
        bool buyPaused
    ) external;

    function isSupplyPaused() external view returns (bool);

    function isTransferPaused() external view returns (bool);

    function isWithdrawPaused() external view returns (bool);

    function isAbsorbPaused() external view returns (bool);

    function isBuyPaused() external view returns (bool);

    function accrueAccount(address account) external;

    function getSupplyRate(uint utilization) external view returns (uint64);

    function getBorrowRate(uint utilization) external view returns (uint64);

    function getUtilization() external view returns (uint);

    function governor() external view returns (address);

    function pauseGuardian() external view returns (address);

    function baseToken() external view returns (address);

    function baseTokenPriceFeed() external view returns (address);

    function extensionDelegate() external view returns (address);

    function userCollateral(address, address) external returns (UserCollateral memory);

    /// @dev uint64
    function supplyKink() external view returns (uint);

    /// @dev uint64
    function supplyPerSecondInterestRateSlopeLow() external view returns (uint);

    /// @dev uint64
    function supplyPerSecondInterestRateSlopeHigh() external view returns (uint);

    /// @dev uint64
    function supplyPerSecondInterestRateBase() external view returns (uint);

    /// @dev uint64
    function borrowKink() external view returns (uint);

    /// @dev uint64
    function borrowPerSecondInterestRateSlopeLow() external view returns (uint);

    /// @dev uint64
    function borrowPerSecondInterestRateSlopeHigh() external view returns (uint);

    /// @dev uint64
    function borrowPerSecondInterestRateBase() external view returns (uint);

    /// @dev uint64
    function storeFrontPriceFactor() external view returns (uint);

    /// @dev uint64
    function baseScale() external view returns (uint);

    /// @dev uint64
    function trackingIndexScale() external view returns (uint);

    /// @dev uint64
    function baseTrackingSupplySpeed() external view returns (uint);

    /// @dev uint64
    function baseTrackingBorrowSpeed() external view returns (uint);

    /// @dev uint104
    function baseMinForRewards() external view returns (uint);

    /// @dev uint104
    function baseBorrowMin() external view returns (uint);

    /// @dev uint104
    function targetReserves() external view returns (uint);

    function numAssets() external view returns (uint8);

    function decimals() external view returns (uint8);

    function initializeStorage() external;
}
