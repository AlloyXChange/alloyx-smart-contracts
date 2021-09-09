// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title TokenReceiver
 * @dev The source network vault that holds all deposits on the source chain. This vault manages deposits and redemptions for source network deposits.
 */
contract TokenVault is AccessControl {
  ERC20 public tokenContract;
  address public vaultOwner;

  bytes32 public constant VALT_OPERATOR = keccak256("VALT_OPERATOR");
  bytes32 public constant ADMIN = keccak256("ADMIN");

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
    _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    grantRole(VALT_OPERATOR, msg.sender);
    grantRole(VALT_OPERATOR, vaultOwner);
    grantRole(ADMIN, admin);
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
    require(hasRole(ADMIN, msg.sender), "Not a admin");

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
    require(hasRole(VALT_OPERATOR, msg.sender), "Not a operator");
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
    require(hasRole(VALT_OPERATOR, msg.sender), "Not a operator");

    address from = msg.sender;

    for (uint256 i = 0; i < stableCoins.length; i++) {
      address rToken = stableCoins[i];
      address rTokenAddress = stableCoins[i];
      if (rewardToken == rTokenAddress) {
        ERC20(rToken).transferFrom(from, address(this), amount);
      }
    }

    uint256 currentBalance = ERC20(rewardToken).balanceOf(address(this));
    DepositRecord memory newRecord = DepositRecord(rewardToken, currentBalance);
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
    require(hasRole(VALT_OPERATOR, msg.sender), "Not a operator");
    address from = msg.sender;
    tokenContract.transferFrom(from, address(this), amount);
    primaryTokenSupply = tokenContract.balanceOf(address(this));

    emit Deposit(from);
  }

  function withdraw(uint256 amount) external {
    require(isWithdrawEnabled == true, "Withdraw not enabled");
    require(hasRole(VALT_OPERATOR, msg.sender), "Not a operator");

    address from = msg.sender;
    tokenContract.approve(from, amount);
    tokenContract.transfer(from, amount);
    emit Withdraw(from);
  }
}
