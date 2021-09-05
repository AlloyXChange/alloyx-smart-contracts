// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DestinationBondToken.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title TokenVaultManager
 * @dev Token vault service.
 */
contract DesinationTokenFactory {
  mapping(address => address[]) public vaultLookup;

  /**
   * @dev Constructor sets token that can be received
   */
  constructor() {}

  /**
   * @dev Pass a vault address and get corresponding destination token
   * 

   * Requirements:
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
   * @dev Deploy destination token
   * 

   *

   * Requirements:
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