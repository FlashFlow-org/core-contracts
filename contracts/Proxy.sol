// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IAddressesProvider } from './interfaces/IAddressesProvider.sol';
import { Errors } from './lib/Errors.sol';

/**
 * @title Proxy
 * @author FlashFlow
 * @notice Contract used as proxy for the user account.
 * @dev This abstract contract provides a fallback function that delegates all calls to another contract using the EVM
 * instruction `delegatecall`.
 *
 * Additionally, delegation to the implementation can be triggered manually through the {_fallback} function, or to a
 * different contract through the {_delegate} function.
 *
 * The success and return data of the delegated call will be returned back to the caller of the proxy.
 */
contract Proxy {
    // The contract by which all other contact addresses are obtained.
    IAddressesProvider public immutable ADDRESSES_PROVIDER;

    constructor(address _provider) {
        ADDRESSES_PROVIDER = IAddressesProvider(_provider);
    }

    /**
     * @dev Delegates the current call to `implementation`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _delegate(address implementation) internal virtual {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    /**
     * @dev Delegates the current call to the address returned by `getImplementation()`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _fallback() internal {
        address _implementation = ADDRESSES_PROVIDER.getAccountImpl();
        require(_implementation != address(0), Errors.INVALID_IMPLEMENTATION_ADDRESS);
        _delegate(_implementation);
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `getImplementation()`.
     * Will run if no other function in the contract matches the call data.
     */
    fallback() external payable {
        _fallback();
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `getImplementation()`.
     * Will run if call data is empty.
     */
    receive() external payable {
        _fallback();
    }
}
