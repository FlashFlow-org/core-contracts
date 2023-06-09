// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title Errors library
 * @author FlashFlow
 * @notice Defines the error messages emitted by the different contracts of the FlashFlow protocol
 */
library Errors {
    // The caller of the function is not a account owner
    string public constant CALLER_NOT_ACCOUNT_OWNER = '1';
    // The caller of the function is not a account contract
    string public constant CALLER_NOT_RECEIVER = '2';
    // The caller of the function is not a flash aggregatoor contract
    string public constant CALLER_NOT_FLASH_AGGREGATOR = '3';
    // The caller of the function is not a position owner
    string public constant CALLER_NOT_POSITION_OWNER = '4';
    // The address of the pool addresses provider is invalid
    string public constant INVALID_ADDRESSES_PROVIDER = '5';
    // The initiator of the flashloan is not a account contract
    string public constant INITIATOR_NOT_ACCOUNT = '6';
    // Failed to charge the protocol fee
    string public constant CHARGE_FEE_NOT_COMPLETED = '7';
    // The sender does not have an account
    string public constant ACCOUNT_DOES_NOT_EXIST = '9';
    // Invalid amount to charge fee
    string public constant INVALID_CHARGE_AMOUNT = '10';
    // There is no connector with this name
    string public constant NOT_CONNECTOR = '11';
    // The address of the connector is invalid
    string public constant INVALID_CONNECTOR_ADDRESS = '12';
    // The length of the connector array and their names are different
    string public constant INVALID_CONNECTORS_LENGTH = '13';
    // A connector with this name already exists
    string public constant CONNECTOR_ALREADY_EXIST = '14';
    // A connector with this name does not exist
    string public constant CONNECTOR_DOES_NOT_EXIST = '15';
    // The caller of the function is not a configurator
    string public constant CALLER_NOT_CONFIGURATOR = '16';
    // The fee amount is invalid
    string public constant INVALID_FEE_AMOUNT = '17';
    // The address of the implementation is invalid
    string public constant INVALID_IMPLEMENTATION_ADDRESS = '18';
    // 'ACL admin cannot be set to the zero address'
    string public constant ACL_ADMIN_CANNOT_BE_ZERO = '19';
    // 'The caller of the function is not a router admin'
    string public constant CALLER_NOT_ROUTER_ADMIN = '20';
    // 'The caller of the function is not an emergency admin'
    string public constant CALLER_NOT_EMERGENCY_ADMIN = '21';
    // 'The caller of the function is not an connector admin'
    string public constant CALLER_NOT_CONNECTOR_ADMIN = '22';
    // Address should be not zero address
    string public constant ADDRESS_IS_ZERO = '23';
    // The caller of the function is not a router contract
    string public constant CALLER_NOT_ROUTER = '24';
    // The call to the open/close callback function failed
    string public constant EXECUTE_OPERATION_FAILED = '25';
    // Invalid amount to leverage
    string public constant LEVERAGE_IS_INVALID = '26';
}
