// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IFlashReceiver } from '../interfaces/IFlashReceiver.sol';
import { IMakerFlashloan } from '../interfaces/connectors/IMakerFlashloan.sol';

import { IERC3156FlashLender } from '../interfaces/external/IERC3156/IERC3156FlashLender.sol';
import { IERC3156FlashBorrower } from '../interfaces/external/IERC3156/IERC3156FlashBorrower.sol';

import { BaseFlashloan } from './BaseFlashloan.sol';

contract MakerFlashloan is IMakerFlashloan, BaseFlashloan {
    /* ============ Constants ============ */

    /**
     * @dev Maker Lending
     */
    IERC3156FlashLender internal immutable LENDING_POOL;

    /**
     * @dev DAI contract address
     */
    address internal immutable DAI_TOKEN;

    /**
     * @dev Connector name
     */
    string public constant override NAME = 'MakerFlashloan';

    /* ============ Constructor ============ */

    /**
     * @dev Constructor.
     * @param _makerLending The address of the AddressesProvider contract
     * @param _daiToken The address of the DAI contract
     */
    constructor(address _makerLending, address _daiToken) {
        LENDING_POOL = IERC3156FlashLender(_makerLending);
        DAI_TOKEN = _daiToken;
    }

    /* ============ External Functions ============ */

    /**
     * @dev Fallback function for makerdao flashloan.
     * @param _initiator initiator address for flashloan.
     * _amount DAI amount for flashloan.
     * _fee fee for the flashloan.
     * @param _data extra data passed(includes route info aswell).
     */
    function onFlashLoan(
        address _initiator,
        address,
        uint256,
        uint256,
        bytes calldata _data
    ) external override verifyDataHash(_data) returns (bytes32) {
        require(_initiator == address(this), 'not same sender');
        require(msg.sender == address(LENDING_POOL), 'not maker sender');

        (address asset, uint256 amount, address sender, bytes memory data) = abi.decode(
            _data,
            (address, uint256, address, bytes)
        );

        uint256 fee = calculateFee(amount, calculateFeeBPS());
        uint256 initialBalance = getBalance(asset);

        safeApprove(asset, amount + fee, address(LENDING_POOL));
        safeTransfer(asset, amount, sender);

        IFlashReceiver(sender).executeOperation(asset, amount, fee, sender, NAME, data);

        require(initialBalance + fee <= getBalance(asset), 'amount paid less');

        return keccak256('ERC3156FlashBorrower.onFlashLoan');
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
        bps = (LENDING_POOL.toll()) / (10 ** 14);
    }

    /* ============ Internal Functions ============ */

    /**
     * @dev Middle function for route 2.
     * @param _token token address for flashloan(DAI).
     * @param _amount DAI amount for flashloan.
     * @param _data extra data passed.
     */
    function _flashLoan(address _token, uint256 _amount, bytes memory _data) internal {
        bytes memory data = abi.encode(_token, _amount, msg.sender, _data);
        _dataHash = bytes32(keccak256(data));
        LENDING_POOL.flashLoan(IERC3156FlashBorrower(address(this)), _token, _amount, data);
    }

    function getAvailability(address _token, uint256 _amount) external view override returns (bool) {
        if (_token == DAI_TOKEN) {
            return _amount <= LENDING_POOL.maxFlashLoan(DAI_TOKEN);
        }
        return false;
    }
}
