// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC20 } from './dependencies/openzeppelin/contracts/IERC20.sol';
import { Address } from './dependencies/openzeppelin/contracts/Address.sol';
import { Initializable } from './dependencies/openzeppelin/upgradeability/Initializable.sol';

import { Errors } from './lib/Errors.sol';
import { DataTypes } from './lib/DataTypes.sol';
import { PercentageMath } from './lib/PercentageMath.sol';
import { ConnectorsCall } from './lib/ConnectorsCall.sol';
import { UniversalERC20 } from './lib/UniversalERC20.sol';

import { IRouter } from './interfaces/IRouter.sol';
import { IAccount } from './interfaces/IAccount.sol';
import { IConnectors } from './interfaces/IConnectors.sol';
import { IBaseFlashloan } from './interfaces/IBaseFlashloan.sol';
import { IAddressesProvider } from './interfaces/IAddressesProvider.sol';

/**
 * @title Account
 * @author FlashFlow
 * @notice Contract used as implimentation user account.
 * @dev Interaction with contracts is carried out by means of calling the proxy contract.
 */
contract Account is Initializable, IAccount {
    using UniversalERC20 for IERC20;
    using ConnectorsCall for IAddressesProvider;
    using Address for address;
    using PercentageMath for uint256;

    /* ============ Immutables ============ */

    // The contract by which all other contact addresses are obtained.
    IAddressesProvider public immutable ADDRESSES_PROVIDER;

    /* ============ State Variables ============ */

    address private _owner;

    /* ============ Events ============ */

    /**
     * @dev Emitted when the tokens is claimed.
     * @param token The address of the token to withdraw.
     * @param amount The amount of the token to withdraw.
     */
    event ClaimedTokens(address token, address owner, uint256 amount);

    /**
     * @dev Emitted when the account take falshlaon.
     * @param token Flashloan token.
     * @param amount Flashloan amount.
     * @param fee Flashloan fee.
     */
    event Flashloan(address indexed token, uint256 amount, uint256 fee);

    /* ============ Modifiers ============ */

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == msg.sender, Errors.CALLER_NOT_ACCOUNT_OWNER);
        _;
    }

    /**
     * @dev Throws if called by any account other than the current contract.
     */
    modifier onlyCallback() {
        require(msg.sender == address(this), Errors.CALLER_NOT_RECEIVER);
        _;
    }

    /**
     * @dev Throws if called by any account other than the router contract.
     */
    modifier onlyRouter() {
        require(msg.sender == address(ADDRESSES_PROVIDER.getRouter()), Errors.CALLER_NOT_ROUTER);
        _;
    }

    /* ============ Initializer ============ */

    /**
     * @dev Constructor.
     * @param provider The address of the AddressesProvider contract
     */
    constructor(address provider) {
        ADDRESSES_PROVIDER = IAddressesProvider(provider);
    }

    /**
     * @dev initialize.
     * @param _user Owner account address.
     * @param _provider The address of the AddressesProvider contract.
     */
    function initialize(address _user, IAddressesProvider _provider) public override initializer {
        require(ADDRESSES_PROVIDER == _provider, Errors.INVALID_ADDRESSES_PROVIDER);
        _owner = _user;
    }

    /* ============ External Functions ============ */

    /**
     * @dev Takes a loan, calls `openPositionCallback` inside the loan, and transfers the commission.
     * @param _position The structure of the current position.
     * @param _targetName The connector name that will be called are.
     * @param _data Calldata for the openPositionCallback.
     */
    function openPosition(
        DataTypes.Position memory _position,
        string memory _targetName,
        bytes calldata _data
    ) external override onlyRouter {
        require(_position.account == _owner, Errors.CALLER_NOT_POSITION_OWNER);
        IERC20(_position.debt).universalTransferFrom(msg.sender, address(this), _position.amountIn);

        uint256 amount = _position.amountIn.mulTo(_position.leverage - PercentageMath.PERCENTAGE_FACTOR);

        flashloan(_position.debt, amount, _targetName, _data);

        require(chargeFee(_position.amountIn + amount, _position.debt), Errors.CHARGE_FEE_NOT_COMPLETED);
    }

    /**
     * @dev Takes a loan, calls `closePositionCallback` inside the loan.
     * @param _key The key to obtain the current position.
     * @param _token Flashloan token.
     * @param _amount Flashloan amount.
     * @param _targetName The connector name that will be called are.
     * @param _data Calldata for the openPositionCallback.
     */
    function closePosition(
        bytes32 _key,
        address _token,
        uint256 _amount,
        string memory _targetName,
        bytes calldata _data
    ) external override onlyRouter {
        (address account, , , , , , ) = getRouter().positions(_key);
        require(account == _owner, Errors.CALLER_NOT_POSITION_OWNER);

        flashloan(_token, _amount, _targetName, _data);
    }

    /**
     * @dev Is called via the caldata within a flashloan.
     * - Swap poisition debt token to collateral token.
     * - Deposit collateral token to the lending protocol.
     * - Borrow debt token to repay flashloan.
     * @param _targetNames The connector name that will be called are.
     * @param _datas Calldata needed to work with the connector `_datas and _targetNames must be with the same index`.
     * @param _customDatas Additional parameters for future use.
     * @param _repayAmount The amount needed to repay the flashloan.
     * @param _repayAddress The amount needed to repay the flashloan.
     */
    function openPositionCallback(
        string[] memory _targetNames,
        bytes[] memory _datas,
        bytes[] calldata _customDatas,
        uint256 _repayAmount,
        address _repayAddress
    ) external override onlyCallback {
        uint256 value = _swap(_targetNames[0], _datas[0]);
        ADDRESSES_PROVIDER.connectorCall(_targetNames[1], abi.encodePacked(_datas[1], value));
        ADDRESSES_PROVIDER.connectorCall(_targetNames[2], abi.encodePacked(_datas[2], _repayAmount));
        DataTypes.Position memory position = getPosition(bytes32(_customDatas[0]));

        position.collateralAmount = value;
        position.borrowAmount = _repayAmount;

        getRouter().updatePosition(position);
        IERC20(position.debt).universalTransfer(_repayAddress, _repayAmount);
    }

    /**
     * @dev Is called via the calldata within a flashloan.
     * - Repay debt token to the lending protocol.
     * - Withdraw collateral token.
     * - Swap poisition collateral token to debt token.
     * @param _targetNames The connector name that will be called are.
     * @param _datas Calldata needed to work with the connector `_datas and _targetNames must be with the same index`.
     * @param _customDatas Additional parameters for future use.
     * @param _repayAmount The amount needed to repay the flashloan.
     * @param _repayAddress The amount needed to repay the flashloan.
     */
    function closePositionCallback(
        string[] memory _targetNames,
        bytes[] memory _datas,
        bytes[] calldata _customDatas,
        uint256 _repayAmount,
        address _repayAddress
    ) external override onlyCallback {
        ADDRESSES_PROVIDER.connectorCall(_targetNames[0], _datas[0]);
        ADDRESSES_PROVIDER.connectorCall(_targetNames[1], _datas[1]);

        uint256 returnedAmt = _swap(_targetNames[2], _datas[2]);

        DataTypes.Position memory position = getPosition(bytes32(_customDatas[0]));

        IERC20(position.debt).universalTransfer(_repayAddress, _repayAmount);
        IERC20(position.debt).universalTransfer(position.account, returnedAmt - _repayAmount);
    }

    /**
     * @dev Takes a loan, and call `callbackFunction` inside the loan.
     * @param _token that was Flashloan.
     * @param _amount Amounts that was Flashloan.
     * @param _fee Loan repayment fee.
     * @param _initiator Address from which the loan was initiated.
     * @param _targetName The connector name that will be called are.
     * @param _params Calldata for the openPositionCallback.
     */
    function executeOperation(
        address _token,
        uint256 _amount,
        uint256 _fee,
        address _initiator,
        string memory _targetName,
        bytes calldata _params
    ) external override {
        require(_initiator == address(this), Errors.INITIATOR_NOT_ACCOUNT);

        address connector = isConnector(_targetName);
        require(connector == msg.sender, Errors.NOT_CONNECTOR);

        bytes memory encodeParams = encodingParams(_params, _amount + _fee, connector);
        address(this).functionCall(encodeParams, Errors.EXECUTE_OPERATION_FAILED);

        emit Flashloan(_token, _amount, _fee);
    }

    /**
     * @dev Owner account claim tokens.
     * @param _token The address of the token to withdraw.
     * @param _amount The amount of the token to withdraw.
     */
    function claimTokens(address _token, uint256 _amount) external override onlyOwner {
        _amount = _amount == 0 ? IERC20(_token).universalBalanceOf(address(this)) : _amount;

        IERC20(_token).universalTransfer(_owner, _amount);

        emit ClaimedTokens(_token, _owner, _amount);
    }

    // solhint-disable-next-line
    receive() external payable {}

    /* ============ Private Functions ============ */

    /**
     * @dev Takes a loan, and call `callbackFunction` inside the loan.
     * @param _token Flashloan token.
     * @param _amount Flashloan amount.
     * @param _targetName The connector name that will be called are.
     * @param _data Calldata for the openPositionCallback.
     */
    function flashloan(address _token, uint256 _amount, string memory _targetName, bytes calldata _data) private {
        address connector = isConnector(_targetName);
        connector.functionCall(abi.encodeWithSelector(IBaseFlashloan.flashLoan.selector, _token, _amount, _data));
    }

    /**
     * @dev Internal function for the exchange, sends tokens to the current contract.
     * @param _name Name of the connector.
     * @param _data Execute calldata.
     * @return value Returns the amount of tokens received.
     */
    function _swap(string memory _name, bytes memory _data) private returns (uint256 value) {
        bytes memory response = ADDRESSES_PROVIDER.connectorCall(_name, _data);
        value = abi.decode(response, (uint256));
    }

    /**
     * @dev Internal function for the charge fee for the using protocol.
     * @param _amount Position amount.
     * @param _token Position token.
     * @return success Returns result of the operation.
     */
    function chargeFee(uint256 _amount, address _token) private returns (bool success) {
        uint256 feeAmount = getRouter().getFeeAmount(_amount);
        success = IERC20(_token).universalTransfer(ADDRESSES_PROVIDER.getTreasury(), feeAmount);
    }

    function isConnector(string memory _name) private view returns (address) {
        address connectors = ADDRESSES_PROVIDER.getConnectors();
        require(connectors != address(0), Errors.ADDRESS_IS_ZERO);

        (bool isOk, address connector) = IConnectors(connectors).isConnector(_name);
        require(isOk, Errors.NOT_CONNECTOR);

        return connector;
    }

    /**
     * @dev Returns the position for the owner.
     * @param _key The key to obtain the current position.
     * @return The structure of the current position.
     */
    function getPosition(bytes32 _key) private view returns (DataTypes.Position memory) {
        (
            address account,
            address debt,
            address collateral,
            uint256 amountIn,
            uint256 sizeDelta,
            uint256 collateralAmount,
            uint256 borrowAmount
        ) = getRouter().positions(_key);
        require(account == _owner, Errors.CALLER_NOT_POSITION_OWNER);
        return DataTypes.Position(account, debt, collateral, amountIn, sizeDelta, collateralAmount, borrowAmount);
    }

    /**
     * @dev Returns an instance of the router class.
     * @return Returns current router contract.
     */
    function getRouter() private view returns (IRouter) {
        return IRouter(ADDRESSES_PROVIDER.getRouter());
    }

    /**
     * @dev Takes a loan, and call `callbackFunction` inside the loan.
     * @param _params parameters for the open and close position callback.
     * @param _amount Loan amount plus loan fee.
     * @param _connector Loan amount plus loan fee.
     * @return encode Merged parameters of the callback and the loan amount.
     */
    function encodingParams(
        bytes memory _params,
        uint256 _amount,
        address _connector
    ) private pure returns (bytes memory encode) {
        (bytes4 selector, string[] memory _targetNames, bytes[] memory _datas, bytes[] memory _customDatas) = abi
            .decode(_params, (bytes4, string[], bytes[], bytes[]));

        encode = abi.encodeWithSelector(selector, _targetNames, _datas, _customDatas, _amount, _connector);
    }
}
