// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title TokenReceiver
 * @dev Very simple example of a contract receiving ERC20 tokens.
 */
contract TokenVault {
    ERC20 public tokenContract;
    address public adminAddress;
    address public vaultOwner;

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

    mapping(address => uint256) private redemptionLookup;
    mapping(address => uint256) public stableCoinAvailable;

    uint256 public deployTime;
    uint256 public maturity;
    uint256 public yield;
    uint256 public primaryTokenSupply;

    bool public isWithdrawEnabled;

    address[] stableCoins;

    event Deposit(address from);
    event Withdraw(address from);

    /**
     * @dev Constructor sets token that can be received
     */
    constructor(
        address token,
        uint256 newMaturity,
        uint256 newYield,
        address contractCreator,
        address admin
    ) {
        maturity = newMaturity;
        deployTime = block.timestamp;
        yield = newYield;
        tokenContract = ERC20(token);
        vaultOwner = contractCreator;
        isWithdrawEnabled = false;
        adminAddress = admin;
    }

    function getStableCoinAvailable(address user)
        public
        view
        returns (uint256)
    {
        return stableCoinAvailable[user];
    }

    function getStableCoins() public view returns (address[] memory) {
        return stableCoins;
    }

    function addToStableCoins(address newToken) public {
        require(vaultOwner == msg.sender, "Not an Owner");
        stableCoins.push(newToken);
    }

    function getERC20Address() public view returns (ERC20) {
        return tokenContract;
    }

    function updateWithrawEnabled(bool value) public {
        require(adminAddress == msg.sender, "Not an Admin");
        isWithdrawEnabled = value;
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

    function approveRedemption(
        address user,
        address rewardToken,
        uint256 amount
    ) public {
        require(vaultOwner == msg.sender, "Not an Owner");
        require(block.timestamp > maturity, "Not at maturity");

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

    function depositIntoStableCoin(address rewardToken, uint256 amount) public {
        require(vaultOwner == msg.sender, "Not an Owner");

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
        require(block.timestamp > maturity, "Not at maturity");

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

    function deposit(uint256 amount) external {
        require(vaultOwner == msg.sender, "Not an Owner");
        address from = msg.sender;
        tokenContract.transferFrom(from, address(this), amount);
        primaryTokenSupply = tokenContract.balanceOf(address(this));

        emit Deposit(from);
    }

    function withdraw(uint256 amount) external {
        require(isWithdrawEnabled == true, "Withdraw not enabled");

        address from = msg.sender;
        tokenContract.approve(from, amount);
        tokenContract.transfer(from, amount);
        emit Withdraw(from);
    }
}
