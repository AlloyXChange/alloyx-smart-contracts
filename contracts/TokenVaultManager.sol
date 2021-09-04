// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TokenVault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title TokenVaultManager
 * @dev Token vault service.
 */
contract TokenVaultManager {
    mapping(address => address[]) public vaultLookup;
    address[] allVaults;
    address admin;

    /**
     * @dev Constructor sets token that can be received
     */
    constructor() {
        admin = msg.sender;
    }

    function getVaultsByUser(address user)
        public
        view
        returns (address[] memory)
    {
        return vaultLookup[user];
    }

    function getAllVaults() public view returns (address[] memory) {
        return allVaults;
    }

    function vaultExists(address erc20Address, address userAddress)
        public
        view
        returns (bool)
    {
        for (uint256 i = 0; i < vaultLookup[userAddress].length; i++) {
            address vaultAddress = vaultLookup[userAddress][i];
            address tokenAddress = address(
                BasicTokenVault(vaultAddress).getERC20Address()
            );
            if (tokenAddress == erc20Address) {
                return true;
            }
        }
        return false;
    }

    function createVault(
        address newToken,
        uint256 maturity,
        uint256 yield,
        address contractCreator
    ) public {
        require(vaultExists(newToken, msg.sender) == false);
        contractCreator = msg.sender;
        address tVault = address(
            new BasicTokenVault(newToken, maturity, yield, msg.sender, admin)
        );
        vaultLookup[msg.sender].push(tVault);
        allVaults.push(tVault);
    }

    function destroyVault(address erc20Address) public {
        address userAddress = msg.sender;
        require(msg.sender == admin, "Not an Admin");

        require(vaultExists(erc20Address, msg.sender) == true);
        uint256 targetIndex;
        bool hasVault = false;
        for (uint256 i = 0; i < vaultLookup[userAddress].length; i++) {
            address vaultAddress = vaultLookup[userAddress][i];
            address tokenAddress = address(
                BasicTokenVault(vaultAddress).getERC20Address()
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
                BasicTokenVault(vaultAddress).getERC20Address()
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
