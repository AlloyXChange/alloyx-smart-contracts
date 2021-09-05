// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TokenVault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title TokenVaultFactory
 */
contract TokenVaultFactory is AccessControl {
  mapping(address => address[]) public vaultLookup;
  address[] allVaults;
  address private admin;
  bytes32 public constant ADMIN = keccak256("ADMIN");

  /**
   * @dev Constructor, provide Admin role to contract deployer
   *

   * Requirements:
   *
   */
  constructor() {
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    admin = msg.sender;
    grantRole(ADMIN, msg.sender);
  }

  /**
   * @dev Given a wallet address, what are the associated vaults
   *

   * Requirements:
   *
   */

  function getVaultsByUser(address user)
    public
    view
    returns (address[] memory)
  {
    return vaultLookup[user];
  }

  /**
   * @dev Get a list of all the vaults
   *

   * Requirements:
   *
   */
  function getAllVaults() public view returns (address[] memory) {
    return allVaults;
  }

  /**
   * @dev Check if the user address already has a vault with the same token
   *
   * TODO: check for expired vaults

   * Requirements:
   *
   */
  function vaultExists(address erc20Address, address userAddress)
    public
    view
    returns (bool)
  {
    for (uint256 i = 0; i < vaultLookup[userAddress].length; i++) {
      address vaultAddress = vaultLookup[userAddress][i];
      address tokenAddress = address(
        TokenVault(vaultAddress).getERC20Address()
      );
      if (tokenAddress == erc20Address) {
        return true;
      }
    }
    return false;
  }

  /**
   * @dev Create a new vault and store it in the registry
   *

   * Requirements:
   * No existing vaults for that user
   */
  function createVault(
    address newToken,
    uint256 maturity,
    uint256 yield,
    address contractCreator
  ) public {
    require(vaultExists(newToken, msg.sender) == false);
    contractCreator = msg.sender;
    address tVault = address(
      new TokenVault(newToken, maturity, yield, contractCreator, admin)
    );
    vaultLookup[msg.sender].push(tVault);
    allVaults.push(tVault);
  }

  /**
   * @dev Remove vault from registry, 
   *

   * Requirements:
   * must be and admin and vault must exist
   */
  function destroyVault(address erc20Address) public {
    address userAddress = msg.sender;
    require(hasRole(ADMIN, msg.sender), "Not a admin");

    require(vaultExists(erc20Address, msg.sender) == true);
    uint256 targetIndex;
    bool hasVault = false;
    for (uint256 i = 0; i < vaultLookup[userAddress].length; i++) {
      address vaultAddress = vaultLookup[userAddress][i];
      address tokenAddress = address(
        TokenVault(vaultAddress).getERC20Address()
      );
      if (tokenAddress == erc20Address) {
        targetIndex = i;
        hasVault = true;
      }
    }
    if (hasVault == true) {
      vaultLookup[userAddress][targetIndex] = vaultLookup[userAddress][
        vaultLookup[userAddress].length - 1
      ];
      vaultLookup[userAddress].pop();
    }

    uint256 allVaultTargetIndex;
    hasVault = false;
    for (uint256 i = 0; i < allVaults.length; i++) {
      address vaultAddress = allVaults[i];

      address tokenAddress = address(
        TokenVault(vaultAddress).getERC20Address()
      );
      if (tokenAddress == erc20Address) {
        allVaultTargetIndex = i;
        hasVault = true;
      }
    }
    if (hasVault == true) {
      allVaults[targetIndex] = allVaults[allVaults.length - 1];
      allVaults.pop();
    }
  }
}
