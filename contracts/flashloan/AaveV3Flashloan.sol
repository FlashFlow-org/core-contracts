// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC20 } from '../dependencies/openzeppelin/contracts/IERC20.sol';

import { IFlashReceiver } from '../interfaces/IFlashReceiver.sol';
import { IAaveV3Flashloan } from '../interfaces/connectors/IAaveFlashloan.sol';

import { IPool } from '../interfaces/external/aave-v3/IPool.sol';
import { IPoolDataProvider } from '../interfaces/external/aave-v3/IPoolDataProvider.sol';

import { BaseFlashloan } from './BaseFlashloan.sol';

contract AaveV3Flashloan is BaseFlashloan, IAaveV3Flashloan {
    /* ============ Constants ============ */

    /**
     * @dev Aave Lending Pool
     */
    IPool internal immutable LENDING_POOL;

    /**
     * @dev Aave Protocol Data Provider
     */
    IPoolDataProvider internal immutable DATA_PROVIDER;

    /**
     * @dev Aave Referral Code
     */
    uint16 internal constant referralCode = 0;

    /**
     * @dev Connector name
     */
    string public constant override NAME = 'AaveV3Flashloan';

    /* ============ Constructor ============ */

    /**
     * @dev Constructor.
     * @param _aaveLending The address of the AddressesProvider contract
     * @param _aaveDataProvider The address of the DataProvider contract
     */
    constructor(address _aaveLending, address _aaveDataProvider) {
        LENDING_POOL = IPool(_aaveLending);
        DATA_PROVIDER = IPoolDataProvider(_aaveDataProvider);
    }

    /* ============ External Functions ============ */

    /**
     * @dev Callback function for aave flashloan.
     * @param _asset list of asset addresses for flashloan.
     * @param _amount list of amounts for the corresponding assets for flashloan.
     * @param _premium list of premiums/fees for the corresponding addresses for flashloan.
     * @param _initiator initiator address for flashloan.
     * @param _data extra data passed.
     */
    function executeOperation(
        address _asset,
        uint256 _amount,
        uint256 _premium,
        address _initiator,
        bytes calldata _data
    ) external override verifyDataHash(_data) returns (bool) {
        require(_initiator == address(this), 'not same sender');
        require(msg.sender == address(LENDING_POOL), 'not aave sender');

        (address sender, bytes memory data) = abi.decode(_data, (address, bytes));

        uint256 initialBalance = getBalance(_asset);

        safeApprove(_asset, _amount + _premium, address(LENDING_POOL));
        safeTransfer(_asset, _amount, sender);

        IFlashReceiver(sender).executeOperation(_asset, _amount, _premium, sender, NAME, data);

        require(initialBalance + _premium <= getBalance(_asset), 'amount paid less');

        return true;
    }

    /**
     * @dev Main function for flashloan for all routes. Calls the middle functions according to routes.
     * @notice Main function for flashloan for all routes. Calls the middle functions according to routes.
     * @param _token token addresses for flashloan.
     * @param _amount list of amounts for the corresponding assets.
     * @param _data extra data passed.
     */
    function flashLoan(address _token, uint256 _amount, bytes calldata _data) external override reentrancy {
        bytes memory data = abi.encode(msg.sender, _data);
        _dataHash = bytes32(keccak256(data));

        LENDING_POOL.flashLoanSimple(address(this), _token, _amount, data, referralCode);
    }

    /* ============ Public Functions ============ */

    /**
     * @dev Returns fee for the passed route in BPS.
     * @notice Returns fee for the passed route in BPS. 1 BPS == 0.01%.
     */
    function calculateFeeBPS() public view override returns (uint256 bps) {
        bps = LENDING_POOL.FLASHLOAN_PREMIUM_TOTAL();
    }

    /* ============ Internal Functions ============ */

    /**
     * @param _token token address for flashloan.
     * @param _amount amount for the corresponding assets or
     * amount of ether to borrow as collateral for flashloan.
     */
    function getAvailability(address _token, uint256 _amount) external view override returns (bool) {
        (, , , , , , , , bool isActive, ) = DATA_PROVIDER.getReserveConfigurationData(_token);
        (address aTokenAddr, , ) = DATA_PROVIDER.getReserveTokensAddresses(_token);
        if (isActive == false || IERC20(_token).balanceOf(aTokenAddr) < _amount) {
            return false;
        }
        return true;
    }
}
