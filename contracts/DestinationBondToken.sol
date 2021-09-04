// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract DestinationBondToken is ERC20, AccessControl {
    mapping(address => uint256) private redemptionLookup;

    address[] tokenHolders;

    struct RedemptionRecord {
        address token;
        address wallet;
        uint256 amount;
        string status;
    }

    struct DepositRecord {
        address token;
        uint256 amount;
    }

    RedemptionRecord[] redemptionRecordList;
    DepositRecord[] depositRecordList;

    address public owner;
    address public contractSender;
    uint256 public vaultMaturity;

    bytes32 public constant WHITELISTED_HOLDER_ROLE =
        keccak256("WHITELISTED_HOLDER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant OPERATOR = keccak256("OPERATOR");
    bytes32 public constant ROUTER_ROLE = keccak256("ROUTER_ROLE");

    uint256 public isWhitelistEnabled = 0;
    string public contractMetadata = "";

    address[] stableCoins;
    uint256 tokenSupply;

    constructor(
        string memory tokenName,
        string memory tokenSymbol,
        string memory metadata,
        uint256 supply,
        address sender,
        uint256 maturity
    ) ERC20(tokenName, tokenSymbol) {
        owner = msg.sender;
        contractSender = sender;
        tokenSupply = supply;
        vaultMaturity = maturity;
        _setupRole(DEFAULT_ADMIN_ROLE, owner);
        contractMetadata = metadata;
        grantRole(WHITELISTED_HOLDER_ROLE, owner);
        grantRole(MINTER_ROLE, contractSender);
        grantRole(OPERATOR, contractSender);
        _mint(contractSender, supply * (10**uint256(decimals())));
    }

    function updateContractMetadata(string memory newData) public {
        contractMetadata = newData;
    }

    function enableWhitelist(uint256 newValue) public {
        require(hasRole(OPERATOR, msg.sender), "Not a operator");
        isWhitelistEnabled = newValue;
    }

    function checkWhitelist() public view returns (uint256) {
        return isWhitelistEnabled;
    }

    function mint(address to, uint256 amount) public {
        // require that the requester have the role of Minter
        require(hasRole(MINTER_ROLE, msg.sender), "Not a minter");
        _mint(to, amount * (10**uint256(decimals())));
    }

    function getRedemptionAvailableForUser(address user)
        public
        view
        returns (uint256)
    {
        return redemptionLookup[user];
    }

    function getRedemptionAmount(address rewardToken, address user)
        public
        view
        returns (uint256)
    {
        for (uint256 i = 0; i < redemptionRecordList.length; i++) {
            RedemptionRecord memory record = redemptionRecordList[i];
            if (record.wallet == user && record.token == rewardToken) {
                return record.amount;
            }
        }
        return 0;
    }

    function getRedemptionStatus(address rewardToken, address user)
        public
        view
        returns (string memory)
    {
        for (uint256 i = 0; i < redemptionRecordList.length; i++) {
            RedemptionRecord memory record = redemptionRecordList[i];
            if (record.wallet == user && record.token == rewardToken) {
                return record.status;
            }
        }
        return "no record";
    }

    function startRedeem(uint256 amount, address forUser) external {
        require(block.timestamp > vaultMaturity, "Not at maturity");
        require(hasRole(OPERATOR, msg.sender), "Not a operator");

        _burn(forUser, amount);
        redemptionLookup[forUser] += amount;
    }

    function approveRedemption(
        address user,
        address rewardToken,
        uint256 amount
    ) public {
        require(hasRole(OPERATOR, msg.sender), "Not a operator");
        require(block.timestamp > vaultMaturity, "Not at maturity");

        for (uint256 i = 0; i < stableCoins.length; i++) {
            address rToken = stableCoins[i];
            if (rToken == rewardToken) {
                RedemptionRecord memory newRecord = RedemptionRecord(
                    stableCoins[i],
                    user,
                    amount,
                    "pending"
                );
                redemptionRecordList.push(newRecord);
            }
        }
    }

    function markRedeemed(uint256 amount, address account) external {
        require(hasRole(OPERATOR, msg.sender), "Not a operator");
        redemptionLookup[account] -= amount;
    }

    //all token transfers must have a recpient in the whitelist
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        tokenHolders.push(to);
        require(
            _validRecipient(to, msg.sender),
            "ERC20WithSafeTransfer: invalid recipient"
        );
    }

    function getStableCoins() public view returns (address[] memory) {
        return stableCoins;
    }

    function getTokenHolders() public view returns (address[] memory) {
        return tokenHolders;
    }

    function addToStableCoins(address newToken) public {
        require(hasRole(OPERATOR, msg.sender), "Not a operator");
        stableCoins.push(newToken);
    }

    function getTokenVaultBalance(address rewardToken)
        public
        view
        returns (uint256)
    {
        uint256 highAmount = 0;
        for (uint256 i = 0; i < depositRecordList.length; i++) {
            DepositRecord memory record = depositRecordList[i];
            if (record.token == rewardToken && record.amount > highAmount) {
                highAmount = record.amount;
            }
        }
        return highAmount;
    }

    function depositIntoStableCoin(address rewardToken, uint256 amount) public {
        require(hasRole(OPERATOR, msg.sender), "Not a operator");
        address from = msg.sender;

        for (uint256 i = 0; i < stableCoins.length; i++) {
            address rToken = stableCoins[i];
            address rTokenAddress = stableCoins[i];
            if (rewardToken == rTokenAddress) {
                ERC20(rToken).transferFrom(from, address(this), amount);
            }
        }

        uint256 currentBalance = ERC20(rewardToken).balanceOf(address(this));
        DepositRecord memory newRecord = DepositRecord(
            rewardToken,
            currentBalance
        );
        depositRecordList.push(newRecord);
    }

    function redeemFromStableCoin(address rewardToken, address tokenHolder)
        public
    {
        require(block.timestamp > vaultMaturity, "Not at maturity");

        address from = msg.sender;
        uint256 redeemAmount = 0;
        for (uint256 i = 0; i < redemptionRecordList.length; i++) {
            if (
                redemptionRecordList[i].wallet == tokenHolder &&
                redemptionRecordList[i].token == rewardToken
            ) {
                if (
                    keccak256(bytes(redemptionRecordList[i].status)) !=
                    keccak256(bytes("paid"))
                ) {
                    redeemAmount = redemptionRecordList[i].amount;
                }
            }
        }

        for (uint256 i = 0; i < stableCoins.length; i++) {
            address rToken = stableCoins[i];
            address rTokenAddress = stableCoins[i];
            if (rewardToken == rTokenAddress) {
                ERC20(rToken).approve(from, redeemAmount);
                ERC20(rToken).transfer(from, redeemAmount);
            }
        }

        for (uint256 z = 0; z < redemptionRecordList.length; z++) {
            if (
                redemptionRecordList[z].wallet == tokenHolder &&
                redemptionRecordList[z].token == rewardToken
            ) {
                redemptionRecordList[z].status = "paid";
            }
        }
    }

    // validate the recipeient is in the whitelist
    function _validRecipient(address to, address sender)
        private
        view
        returns (bool)
    {
        if (isWhitelistEnabled == 0) {
            return true;
        }

        if (hasRole(ROUTER_ROLE, sender)) {
            return true;
        }

        require(
            hasRole(WHITELISTED_HOLDER_ROLE, to),
            "Recipient does not have access"
        );
        return true;
    }
}
