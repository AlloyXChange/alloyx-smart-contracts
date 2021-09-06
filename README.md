# Smart Contracts for AlloyX

## Summary

AlloyX is a protocol that allows for the safe transfer of ERC20s from one EVM network to another. With a time locked vault the protocol enables user generated bundles of whitelisted ERC20s.
Vaults can hold a collection of ERC20s and at maturity, payout a distribution to the destination chain token holders. The payout amounts are determined by the destination token holder's proportion of the overall supply. The vault operator is responsible for redemptions in both vault types.

A vault operator starts by selecting which type of vault they would like:

1.  **Primary Token Vault**

    This vault locks a whitelisted ERC20 as a primary token. This primary token is most likely tied to a Real World Asset. Where the operator deposits and locks their bond tokens while committing to paying token holders an expected yield. The primary token is not available to token holders at maturity. Instead, the vault operator deposits one or more ERC20s (such as DAI, USDC, or cUSD) and are redeemable to the token holders at maturity.

    - The vault holder is incentivized to process redemptions with reward tokens (ALLOYX). The rewards are not available to the vault operator until all token holders are marked eligible.

      - Also, the primary tokens are only available to the vault operator after all token holders have been marked as redeemable.

    - Token supply matches the primarty token deposit 1:1.

2.  **Open Vault**

    This vault locks one or more whitelisted ERC20s and are all redeemable by token holders at the time of maturity. There is no primary token.

    - The vault operator determines the total token supply

    - The vault holder is incentivized to process redemptions due to their receipt of reward tokens (ALLOYX). The rewards are not available to the vault creator until all token holders are marked eligible.

## Core Features:

**Whitelisted Token Holders**

All destination tokens have an optional feature to enforce whitelisting on who can receive the token. This includes a limit on the total number of token holders.

**Whitelisted Addresses**

All ERC20 address that enter into the AlloyX are verified and enabled via the ALLOYX governence token. The community approves the addition and or subtraction of whitelisted tokens.

**Transparent Asset Value**

All destination tokens come with embedded metadata detailing the underlying asset value. This is stored via an IPFS hash that is updated in the AlloyX Dapp.

**Redemption**

Upon maturity, the vault operator uses the protocol to approve the token holder's balance and deduct their supply of destination tokens. This creates a record in the vault enabling redemption for all token holders.

When all token holders have been marked as approved, the vault operator can redeem their ALLOYX token rewards and if it is a primary token vault, redeem their primary tokens.

The token holder uses a portal to redeem their vault tokens.

## Contract Roles and Responsibilities

All contracts use the open source AccessControl library provided by OpenZeppelin to manage identity and access.

`DestinationBondToken.sol`: The token contract representing the vault and made available on the destination network. An ERC20 based on OpenZeppelins latest AccessControl and ERC20 interfaces. This token holds the follwing responsibilities:

1. Hold a list of whitelisted token holders for which the operator has control.
2. Can hold the vault for destination vault deposits.
3. Manages list of token holders
4. Manage deposits and redemptions for destination deposits

`DestinationTokenFactory.sol`: This factory creates DestinationBondTokens and manages a registry of the requesting vault addresses as the key and bond token as the value.

`TokenVault.sol`: The source network vault that holds all deposits on the source chain. This vault manages deposits and redemptions for source network deposits.

`TokenVaultFactory.sol`: A source network factory that both creates vaults manages a registry of the source vault and it's address.

`Access.sol`: Control who has access to the web dapp.

## Contract Deployment

First run `npm install` and configure your deployment addresses as `.secrets`. Also, for Ethereum deployments you'll need to provide your Infura key.

**Source Network**

For deployment to a source network, such as Ethereum use the following commands:

`truffle migrate -f 3 --to 3 --network ropsten`

`truffle migrate -f 3 --to 3 --network rinkeby`

This will deploy the TokenVault and TokenVault Factory smart contracts. With the factory contract deployed, new vaults are created by calling `createVault()` with the necessary paramaters

**Destination Network**

For deployment to a destination network, such as Celo use the following commands:

`truffle migrate -f 6 --to 6 --network alfajores`

This will deploy a DestinationTokenFactory and DestinationBondToken.
