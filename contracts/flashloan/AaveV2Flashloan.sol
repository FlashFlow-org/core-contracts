// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC20 } from '../dependencies/openzeppelin/contracts/IERC20.sol';

import { IFlashReceiver } from '../interfaces/IFlashReceiver.sol';
import { IAaveV2Flashloan } from '../interfaces/connectors/IAaveFlashloan.sol';

import { ILendingPool } from '../interfaces/external/aave-v2/ILendingPool.sol';
import { IProtocolDataProvider } from '../interfaces/external/aave-v2/IProtocolDataProvider.sol';

import { BaseFlashloan } from './BaseFlashloan.sol';

contract AaveV2Flashloan is BaseFlashloan, IAaveV2Flashloan {
    /* ============ Constants ============ */

    /**
     * @dev Aave Lending Pool
     */
    ILendingPool internal immutable LENDING_POOL;

    /**
     * @dev Aave Protocol Data Provider
     */
    IProtocolDataProvider internal immutable DATA_PROVIDER;

    /**
     * @dev Connector name
     */
    string public constant override NAME = 'AaveV2Flashloan';

    /* ============ Constructor ============ */

    /**
     * @dev Constructor.
     * @param _aaveLending The address of the AddressesProvider contract
     * @param _aaveDataProvider The address of the DataProvider contract
     */
    constructor(address _aaveLending, address _aaveDataProvider) {
        LENDING_POOL = ILendingPool(_aaveLending);
        DATA_PROVIDER = IProtocolDataProvider(_aaveDataProvider);
    }

    /* ============ External Functions ============ */

    /**
     * @dev Callback function for aave flashloan.
     * @param _assets list of asset addresses for flashloan.
     * @param _amounts list of amounts for the corresponding assets for flashloan.
     * @param _premiums list of premiums/fees for the corresponding addresses for flashloan.
     * @param _initiator initiator address for flashloan.
     * @param _data extra data passed.
     */
    function executeOperation(
        address[] memory _assets,
        uint256[] memory _amounts,
        uint256[] memory _premiums,
        address _initiator,
        bytes memory _data
    ) external override verifyDataHash(_data) returns (bool) {
        require(_initiator == address(this), 'not same sender');
        require(msg.sender == address(LENDING_POOL), 'not aave sender');

        (address sender, bytes memory data) = abi.decode(_data, (address, bytes));

        address asset = _assets[0];
        uint256 amount = _amounts[0];
        uint256 fee = _premiums[0];

        uint256 initialBalance = getBalance(asset);

        safeApprove(asset, amount + fee, address(LENDING_POOL));
        safeTransfer(asset, amount, sender);

        IFlashReceiver(sender).executeOperation(asset, amount, fee, sender, NAME, data);

        require(initialBalance + fee <= getBalance(asset), 'amount paid less');

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
        _flashLoan(_token, _amount, _data);
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
     * @param _data extra data passed.
     */
    function _flashLoan(address _token, uint256 _amount, bytes memory _data) internal {
        bytes memory data = abi.encode(msg.sender, _data);
        _dataHash = bytes32(keccak256(data));

        address[] memory tokens = new address[](1);
        tokens[0] = _token;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _amount;

        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        LENDING_POOL.flashLoan(address(this), tokens, amounts, modes, address(0), data, 0);
    }

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
