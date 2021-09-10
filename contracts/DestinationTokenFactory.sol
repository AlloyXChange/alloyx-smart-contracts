// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// ============ Internal Imports ============
import "./DestinationBondToken.sol";

// ============ External Imports ============
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title TokenVaultManager
 * @dev Destination token vault factory.
 */
contract DesinationTokenFactory {
  mapping(address => address[]) public vaultLookup;

  constructor() {}

  /**
   * @notice Pass a vault address and get corresponding destination token
   * @param vault The vault address for which you would like the corresponding destination token
   * @return Returns the address of the destination token:
   *
   */
  function getTokenByVault(address vault)
    public
    view
    returns (address[] memory)
  {
    return vaultLookup[vault];
  }

  /**
   * @notice Deploy destination token
   * @param vaultAddress The source network address of the token
   * @param tokenName Name of the destination token
   * @param tokenSymbol Symbol of the destination token
   * @param metadata IPFS hash for unerlying assets metadata
   * @param supply Inital supply of tokens
   * @param owner Onwer of the source contract
   * @param maturity Time in the future when tokens are redeemable
   *
   */
  function deployDestinationToken(
    address vaultAddress,
    string memory tokenName,
    string memory tokenSymbol,
    string memory metadata,
    uint256 supply,
    address owner,
    uint256 maturity
  ) public {
    address newToken = address(
      new DestinationBondToken(
        tokenName,
        tokenSymbol,
        metadata,
        supply,
        owner,
        maturity
      )
    );
    vaultLookup[vaultAddress].push(newToken);
  }
}
