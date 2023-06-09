// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC20 } from './dependencies/openzeppelin/contracts/IERC20.sol';
import { Clones } from './dependencies/openzeppelin/upgradeability/Clones.sol';
import { VersionedInitializable } from './dependencies/upgradeability/VersionedInitializable.sol';

import { Errors } from './lib/Errors.sol';
import { DataTypes } from './lib/DataTypes.sol';
import { ConnectorsCall } from './lib/ConnectorsCall.sol';
import { PercentageMath } from './lib/PercentageMath.sol';
import { UniversalERC20 } from './lib/UniversalERC20.sol';

import { IRouter } from './interfaces/IRouter.sol';
import { IAccount } from './interfaces/IAccount.sol';
import { IConnectors } from './interfaces/IConnectors.sol';
import { IAddressesProvider } from './interfaces/IAddressesProvider.sol';

/**
 * @title Router contract
 * @author FlashFlow
 * @notice Main point of interaction with an FlashFlow protocol
 * - Users can:
 *   # Open position
 *   # Close position
 *   # Swap their tokens
 *   # Create acconut
 */
contract Router is VersionedInitializable, IRouter {
    using UniversalERC20 for IERC20;
    using ConnectorsCall for IAddressesProvider;
    using PercentageMath for uint256;

    /* ============ Immutables ============ */

    // The contract by which all other contact addresses are obtained.
    IAddressesProvider public immutable ADDRESSES_PROVIDER;

    /* ============ Constants ============ */

    uint256 public constant ROUTER_REVISION = 0x1;

    /* ============ State Variables ============ */

    // Fee of the protocol, expressed in bps
    uint256 public override fee;

    // Count of user position
    mapping(address => uint256) public override positionsIndex;

    // Map of key (user address and position index) to position (key => postion)
    mapping(bytes32 => DataTypes.Position) public override positions;

    // Map of users address and their account (userAddress => userAccount)
    mapping(address => address) public override accounts;

    /* ============ Events ============ */

    /**
     * @dev Emitted when the account will be created.
     * @param account The address of the Account contract.
     * @param owner The address of the owner account.
     */
    event AccountCreated(address indexed account, address indexed owner);

    /**
     * @dev Emitted when the sender swap tokens.
     * @param sender Address who create operation.
     * @param fromToken The address of the token to sell.
     * @param toToken The address of the token to buy.
     * @param amountIn The amount of the token to sell.
     * @param amountOut The amount of the token transfer to sender.
     * @param connectorName Conenctor name.
     */
    event SwapTokens(
        address indexed sender,
        address fromToken,
        address toToken,
        uint256 amountIn,
        uint256 amountOut,
        string connectorName
    );

    /**
     * @dev Emitted when the user open position.
     * @param key The key to obtain the current position.
     * @param account The address of the owner position.
     * @param index Count current position.
     * @param position The structure of the current position.
     */
    event OpenPosition(bytes32 indexed key, address indexed account, uint256 index, DataTypes.Position position);

    /**
     * @dev Emitted when the user close position.
     * @param key The key to obtain the current position.
     * @param account The address of the owner position.
     * @param position The structure of the current position.
     */
    event ClosePosition(bytes32 indexed key, address indexed account, DataTypes.Position position);

    /* ============ Modifiers ============ */

    /**
     * @dev Only pool configurator can call functions marked by this modifier.
     */
    modifier onlyConfigurator() {
        require(ADDRESSES_PROVIDER.getConfigurator() == msg.sender, Errors.CALLER_NOT_CONFIGURATOR);
        _;
    }

    /* ============ Constructor ============ */

    /**
     * @dev Constructor.
     * @param _provider The address of the AddressesProvider contract
     */
    constructor(IAddressesProvider _provider) {
        require(address(_provider) != address(0), Errors.ADDRESS_IS_ZERO);
        ADDRESSES_PROVIDER = _provider;
    }

    /* ============ Initializer ============ */

    /**
     * @notice Initializes the Router.
     * @dev Function is invoked by the proxy contract when the Router contract is added to the
     * AddressesProvider.
     * @dev Caching the address of the AddressesProvider in order to reduce gas consumption on subsequent operations
     * @param _provider The address of the AddressesProvider
     */
    function initialize(address _provider) external virtual initializer {
        require(_provider == address(ADDRESSES_PROVIDER), Errors.INVALID_ADDRESSES_PROVIDER);
        fee = 50; // 0.5%
    }

    /* ============ External Functions ============ */

    /**
     * @notice Set a new fee to the router contract.
     * @param _fee The new amount
     */
    function setFee(uint256 _fee) external override onlyConfigurator {
        require(_fee > 0, Errors.INVALID_FEE_AMOUNT);
        fee = _fee;
    }

    /**
     * @dev Exchanges the input token for the necessary token to create a position and opens it.
     * @param _position The structure of the current position.
     * @param _targetName The connector name that will be called are.
     * @param _data Calldata for the openPositionCallback.
     * @param _params The additional parameters needed to the exchange.
     */
    function swapAndOpen(
        DataTypes.Position memory _position,
        string memory _targetName,
        bytes calldata _data,
        SwapParams memory _params
    ) external payable override {
        _position.amountIn = _swap(_params);
        _openPosition(_position, _targetName, _data);
    }

    /**
     * @dev Create a position on the lendings protocol.
     * @param _position The structure of the current position.
     * @param _targetName The connector name that will be called are.
     * @param _data Calldata for the openPositionCallback.
     */
    function openPosition(
        DataTypes.Position memory _position,
        string memory _targetName,
        bytes calldata _data
    ) external override {
        IERC20(_position.debt).universalTransferFrom(msg.sender, address(this), _position.amountIn);
        _openPosition(_position, _targetName, _data);
    }

    /**
     * @dev Сloses the user's position and deletes it.
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
    ) external override {
        DataTypes.Position memory position = positions[_key];
        require(msg.sender == position.account, Errors.CALLER_NOT_POSITION_OWNER);

        address account = accounts[msg.sender];
        require(account != address(0), Errors.ACCOUNT_DOES_NOT_EXIST);

        IAccount(account).closePosition(_key, _token, _amount, _targetName, _data);

        emit ClosePosition(_key, account, position);
        delete positions[_key];
    }

    /**
     * @dev Exchanges tokens and sends them to the sender, an auxiliary function for the user interface.
     * @param _params parameters required for the exchange.
     */
    function swap(SwapParams memory _params) external payable override {
        uint256 initialBalance = IERC20(_params.toToken).universalBalanceOf(address(this));
        uint256 value = _swap(_params);
        uint256 finalBalance = IERC20(_params.toToken).universalBalanceOf(address(this));
        require(finalBalance - initialBalance == value, 'value is not valid');

        IERC20(_params.toToken).universalTransfer(msg.sender, value);

        emit SwapTokens(msg.sender, _params.fromToken, _params.toToken, _params.amount, value, _params.targetName);
    }

    /**
     * @dev Updates the current positions required for the callback.
     * @param _position The structure of the current position.
     */
    function updatePosition(DataTypes.Position memory _position) external override {
        address account = _position.account;
        require(msg.sender == accounts[account], Errors.CALLER_NOT_ACCOUNT_OWNER);

        bytes32 key = getKey(account, positionsIndex[account]);
        positions[key] = _position;
    }

    // solhint-disable-next-line
    receive() external payable {}

    /* ============ Public Functions ============ */

    /**
     * @dev Checks if the user has an account otherwise creates and initializes it.
     * @param _owner User address.
     * @return Returns of the user account address.
     */
    function getOrCreateAccount(address _owner) public override returns (address) {
        require(_owner == msg.sender, Errors.CALLER_NOT_ACCOUNT_OWNER);
        address _account = address(accounts[_owner]);

        if (_account == address(0)) {
            _account = Clones.cloneDeterministic(
                ADDRESSES_PROVIDER.getAccountProxy(),
                bytes32(abi.encodePacked(_owner))
            );
            accounts[_owner] = _account;
            IAccount(_account).initialize(_owner, ADDRESSES_PROVIDER);
            emit AccountCreated(_account, _owner);
        }

        return _account;
    }

    /**
     * @dev Create position key.
     * @param _account Position account owner.
     * @param _index Position count account owner.
     * @return Returns the position key
     */
    function getKey(address _account, uint256 _index) public pure override returns (bytes32) {
        return keccak256(abi.encodePacked(_account, _index));
    }

    /**
     * @dev Returns the future address of the account created through create2, necessary for the user interface.
     * @param _owner User account address, convert to salt.
     * @return predicted Returns of the user account address.
     */
    function predictDeterministicAddress(address _owner) public view override returns (address predicted) {
        return
            Clones.predictDeterministicAddress(
                ADDRESSES_PROVIDER.getAccountProxy(),
                bytes32(abi.encodePacked(_owner)),
                address(this)
            );
    }

    /**
     * @dev Calculates and returns the current commission depending on the amount.
     * @param _amount Amount
     * @return feeAmount Returns the protocol fee amount.
     */
    function getFeeAmount(uint256 _amount) public view override returns (uint256 feeAmount) {
        require(_amount > 0, Errors.INVALID_CHARGE_AMOUNT);
        feeAmount = _amount.mulTo(fee);
    }

    /* ============ Private Functions ============ */

    /**
     * @dev Create user account if user doesn't have it. Update position index and position state.
     * Call openPosition on the user account proxy contract.
     */
    function _openPosition(
        DataTypes.Position memory _position,
        string memory _targetName,
        bytes calldata _data
    ) private {
        require(_position.account == msg.sender, Errors.CALLER_NOT_POSITION_OWNER);
        require(_position.leverage > PercentageMath.PERCENTAGE_FACTOR, Errors.LEVERAGE_IS_INVALID);

        address account = getOrCreateAccount(msg.sender);

        address owner = _position.account;
        uint256 index = positionsIndex[owner] += 1;
        positionsIndex[owner] = index;

        bytes32 key = getKey(owner, index);
        positions[key] = _position;

        IERC20(_position.debt).universalApprove(account, _position.amountIn);
        IAccount(account).openPosition(_position, _targetName, _data);

        // Get the position on the key because, update it in the process of creating
        emit OpenPosition(key, account, index, positions[key]);
    }

    /**
     * @dev Internal function for the exchange, sends tokens to the current contract.
     * @param _params parameters required for the exchange.
     * @return value  Returns the amount of tokens received.
     */
    function _swap(SwapParams memory _params) private returns (uint256 value) {
        IERC20(_params.fromToken).universalTransferFrom(msg.sender, address(this), _params.amount);
        bytes memory response = ADDRESSES_PROVIDER.connectorCall(_params.targetName, _params.data);
        value = abi.decode(response, (uint256));
    }

    /**
     * @notice Returns the version of the Router contract.
     * @return The version is needed to update the proxy.
     */
    function getRevision() internal pure override returns (uint256) {
        return ROUTER_REVISION;
    }
}
