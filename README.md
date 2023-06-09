Contracts
[![codecov](https://codecov.io/gh/FlashFlow-org/core-contracts/branch/master/graph/badge.svg?token=94VIK7W295)](https://codecov.io/gh/FlashFlow-org/core-contracts)

## Overview of the protocol

The protocol creates leveraged positions in existing lending protocols, providing leverage on the means of flash loans.

## Open position process overview

To create a leveraged position, the user must have a collateral token from the list of available tokens on the Lending Protocols. This token will be a collateral to open a trade and it will calculate the PnL position. 

If the user does not have a token from the list, the flash flow protocol will be able to exchange any user token from the list. Directly in the opening of the position without additional trades.

- choose a token based on the CF and LL of that token and available liquidity.
- look for a loan based on the token, amount and loan fee.
- look for a trade and prepare a stake date for it.
- we put together a calldata for a trade, a short-term loan, a deposit and a loan.
- the user gives an approve to the protocol contract. (if the token supports it, it can only be signed).
- trade execution (position opening).

### Domain model

**Possiton**:

- `address` account - owner
- `address` debt - token for the loan
- `address` collateral - security token
- `uint256` amountIn - original amount of the position
- `uint256` leverage - leverage
- `uint256` collateralAmount - amount for the collateral received after the trade 
- `uint256` borrowAmount - amount of the loan for the redemption of the short-term loan and calculation of the fund

**SwapParams**:

- `address` fromToken - input token
- `address` toToken - output token
- `uint256` amount - exchange amount
- `string` targetName - connector name
- `bytes` data - calldata for the exchange

### Commission calculation

- for each position opening, the commission is calculated based on the leveraged transaction amount and the commission set on the contract, the commission can only be changed by the configurator contract.

### Router

- position opening and creation of proxy accounts for users.
- accounts are created by cloning a proxy contract when a position is opened and the user has no account.
- open and closing a position in a token that is not present in the lending protocols, there are methods by which we can make the exchange before opening or after closing a position.
- it stores the data of all user accounts and positions.

### Account

- contains the logic for opening and closing positions.
*Account contains the logic for opening and closing positions.*

### AddressesProvider

- main registry of addresses part of or connected to the protocol.

### Connectors

- sets the addresses for support contracts for interactions with other protocols.
- main registry of connector contract addresses.


### FlashAggregator

- is used to take and return flash loans.
- it works with aave, balancer, maker.
- the parameters are calculated using the flash resolver contract (in the future they will be calculated on the backend).

### FlashResolver

- calculates the parameters for working with flash aggregator.

### Connector

- contains the minimal logic for working with external protocols.
- they are handled by delegatecall.
*There's a thought of making libraries out of them*

### ACLManager

- access control list manager, main registry of system roles and permissions.

### Configurator

- implements the configuration methods for the FlashFlow protocol.

### License

Smart contracts for Flash Flow protocol are available under the [MIT License](LICENSE.md).
