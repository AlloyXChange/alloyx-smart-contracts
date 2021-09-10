// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// ============ Internal Imports ============
import "./TokenVault.sol";

// ============ External Imports ============
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
   * @notice Constructor, provide Admin role to contract deployer
   */
  constructor() {
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    admin = msg.sender;
    grantRole(ADMIN, msg.sender);
  }

  /**
   * @notice Given a wallet address, what are the associated vaults
   *
   * @param user address of the user in the lookup.
   * @return All of the vaults for a given user
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
   * @notice Given a wallet address, what are the associated vaults
   *
   * @return All of the vaults
   *
   */
  function getAllVaults() public view returns (address[] memory) {
    return allVaults;
  }

  /**
   * @notice Check if a vault exists
   * @param erc20Address The primary token
   * @param userAddress address of the user in the lookup.
   * @return BOOL describing whether or not the vault exists
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
   * @notice Check if a vault exists
   * @param newToken The primary token
   * @param maturity When will redemption be made available
   * @param yield The yield of the underlying asset
   * @param contractCreator Address of the vault creator
   *
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
   * @notice Removes a vault from the factory lookup. Only admins can perform this task.
   * @param erc20Address The primary token
   *
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
