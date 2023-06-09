// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Errors } from '../lib/Errors.sol';

import { IConnectors } from '../interfaces/IConnectors.sol';
import { IAddressesProvider } from '../interfaces/IAddressesProvider.sol';

library ConnectorsCall {
    /**
     * @dev They will check if the target is a finite connector, and if it is, they will call it.
     * @param _provider Addresses provider contract address.
     * @param _targetName Name of the connector.
     * @param _data Execute calldata.
     * @return response Returns the result of calling the calldata.
     */
    function connectorCall(
        IAddressesProvider _provider,
        string memory _targetName,
        bytes memory _data
    ) internal returns (bytes memory response) {
        address connectors = _provider.getConnectors();
        require(connectors != address(0), Errors.ADDRESS_IS_ZERO);
        response = _connectorCall(connectors, _targetName, _data);
    }

    /**
     * @dev They will check if the target is a finite connector, and if it is, they will call it.
     * @param _connectors Main connectors contract.
     * @param _targetName Name of the connector.
     * @param _data Execute calldata.
     * @return response Returns the result of calling the calldata.
     */
    function _connectorCall(
        address _connectors,
        string memory _targetName,
        bytes memory _data
    ) private returns (bytes memory response) {
        (bool isOk, address _target) = IConnectors(_connectors).isConnector(_targetName);
        require(isOk, Errors.NOT_CONNECTOR);
        response = _delegatecall(_target, _data);
    }

    /**
     * @dev Delegates the current call to `target`.
     * @param _target Name of the connector.
     * @param _data Execute calldata.
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _delegatecall(address _target, bytes memory _data) private returns (bytes memory response) {
        require(_target != address(0), Errors.INVALID_CONNECTOR_ADDRESS);
        assembly {
            let succeeded := delegatecall(gas(), _target, add(_data, 0x20), mload(_data), 0, 0)
            let size := returndatasize()

            response := mload(0x40)
            mstore(0x40, add(response, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            mstore(response, size)
            returndatacopy(add(response, 0x20), 0, size)

            switch iszero(succeeded)
            case 1 {
                // throw if delegatecall failed
                returndatacopy(0x00, 0x00, size)
                revert(0x00, size)
            }
        }
    }
}
