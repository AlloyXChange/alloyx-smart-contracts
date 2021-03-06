// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// ============ External Imports ============
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title TokeVault
 * @notice The source network vault that holds all deposits on the source chain. This vault manages deposits and redemptions for source network deposits.
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

  /**
   * @notice Get the stable coins
   * @return All of the stable coins
   *
   */
  function getStableCoins() public view returns (address[] memory) {
    return stableCoins;
  }

  /**
   * @notice Adds a stable coin, must be a vault owner
   * @param newToken Add a new token to the redemption pool
   *
   */
  function addToStableCoins(address newToken) public {
    require(vaultOwner == msg.sender, "Not an Owner");
    stableCoins.push(newToken);
  }

  /**
   * @notice Get the ERC20 of the source primary token
   * @return ERC20 for the primary token
   *
   */
  function getERC20Address() public view returns (ERC20) {
    return tokenContract;
  }

  /**
   * @notice Enables withdrawal, only admins can perform this task
   * @param value The state for withdrawal
   *
   */
  function updateWithrawEnabled(bool value) public {
    require(hasRole(ADMIN, msg.sender), "Not a admin");

    isWithdrawEnabled = value;
  }

  /**
   * @notice Gets the high amount of a deposited vault token
   * @param rewardToken The vault token for which you're querying
   * @return The amount of tokens deposited
   *
   */
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

  /**
   * @notice Approves redemption for a given user. Stores the record in a struct.
   * @param user The end user who is a token holder
   * @param rewardToken Token they will redeem
   * @param amount The amount available
   *
   */
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

  /**
   * @notice Read the redemption records for available amount by token end user
   * @param user The end user who is a token holder
   * @param rewardToken Token they will redeem
   * @return The amount they have available
   *
   */
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

  /**
   * @notice Read the redemption status for a token end user
   * @param user The end user who is a token holder
   * @param rewardToken Token they will redeem
   * @return The current record status
   *
   */
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

  /**
   * @notice Deposit into the stable coin reserve
   * @param rewardToken Token they will deposit
   * @param amount The amount the will deposit
   *
   */
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

  /**
   * @notice Redeem from the source stable coins reserve
   * @param rewardToken Token they will redeem
   * @param tokenHolder The token holder address
   *
   */
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

  /**
   * @notice Deposit a primary token into the contract
   * @param amount How much they will deposit.
   *
   */
  function deposit(uint256 amount) external {
    require(hasRole(VALT_OPERATOR, msg.sender), "Not a operator");
    address from = msg.sender;
    tokenContract.transferFrom(from, address(this), amount);
    primaryTokenSupply = tokenContract.balanceOf(address(this));

    emit Deposit(from);
  }

  /**
   * @notice Withdraw primary tokens
   * @param amount How much they will withdraw.
   *
   */
  function withdraw(uint256 amount) external {
    require(isWithdrawEnabled == true, "Withdraw not enabled");
    require(hasRole(VALT_OPERATOR, msg.sender), "Not a operator");

    address from = msg.sender;
    tokenContract.approve(from, amount);
    tokenContract.transfer(from, amount);
    emit Withdraw(from);
  }
}
