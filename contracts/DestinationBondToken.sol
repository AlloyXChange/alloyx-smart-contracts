// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// ============ External Imports ============
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./StringsLib.sol";
import "./Utils.sol";

/**
 * @title DestinationBondToken
 * @notice The destination network vault that holds all deposits on the destination chain. This vault is the tradeable ERC20 and it manages deposits and redemptions for source network deposits.
 */
contract DestinationBondToken is ERC20, AccessControl {
  using StringsLib for string;
  using Utils for *;

  address[] tokenHolders;
  address[] whitelistedWallets;

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

  RedemptionRecord[] private redemptionRecordList;
  DepositRecord[] private depositRecordList;

  mapping(address => uint256) private redemptionLookup;

  address public owner;
  uint256 public vaultMaturity;

  bytes32 public constant WHITELISTED_HOLDER_ROLE =
    keccak256("WHITELISTED_HOLDER_ROLE");
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public constant VALT_OPERATOR = keccak256("VALT_OPERATOR");
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
    tokenSupply = supply;
    vaultMaturity = maturity;
    contractMetadata = metadata;
    _setupRole(DEFAULT_ADMIN_ROLE, owner);
    grantRole(DEFAULT_ADMIN_ROLE, sender);
    grantRole(WHITELISTED_HOLDER_ROLE, sender);
    grantRole(MINTER_ROLE, sender);
    grantRole(VALT_OPERATOR, sender);
    _mint(sender, supply * (10**uint256(decimals())));
    whitelistedWallets.push(sender);
  }

  /**
   * @notice Update the IPFS hash on the destination contract
   * @param newData A string representing the hash
   *
   */
  function updateContractMetadata(string memory newData) public {
    require(hasRole(VALT_OPERATOR, msg.sender), "Not a operator");
    contractMetadata = newData;
  }

  /**
   * @notice Turn on whitelisting for token holders
   * @param newValue A boolean
   *
   */
  function enableWhitelist(uint256 newValue) public {
    require(hasRole(VALT_OPERATOR, msg.sender), "Not a operator");
    isWhitelistEnabled = newValue;
  }

  /**
   * @notice Check for state on whitelisting
   * @return Is it enabled?
   *
   */
  function checkWhitelist() public view returns (uint256) {
    return isWhitelistEnabled;
  }

  function addToWhitelist(string memory wallet) private {
    address walletAsAddress = Utils.parseAddr(wallet);
    grantRole(WHITELISTED_HOLDER_ROLE, walletAsAddress);
    if (!Utils.hasAddressInArray(walletAsAddress, whitelistedWallets)) {
      whitelistedWallets.push(walletAsAddress);
    }
  }

  function batchAddToWhitelist(string memory addresses) public {
    require(hasRole(VALT_OPERATOR, msg.sender), "Not a operator");
    string[] memory list = addresses.split(",");
    for (uint256 i = 0; i < list.length; i++) {
      string memory wallet = list[i];
      addToWhitelist(wallet);
    }
  }

  /**
   * @notice Initial mint of destination token
   * @param to Who will receive the initial tokens, the vault creator
   * @param amount The amount of tokens to mint
   *
   */
  function mint(address to, uint256 amount) public {
    // require that the requester have the role of Minter
    require(hasRole(MINTER_ROLE, msg.sender), "Not a minter");
    _mint(to, amount * (10**uint256(decimals())));
  }

  /**
   * @notice Check how many tokens the holder has redeemed
   * @param user The token holder
   * @return How much they've redeemed
   *
   */
  function getRedemptionAvailableForUser(address user)
    public
    view
    returns (uint256)
  {
    return redemptionLookup[user];
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
   * @notice Burn the tokens and mark them ready for redemption
   * @param amount The amount to burn
   * @param forUser The token holder
   *
   */
  function startRedeem(uint256 amount, address forUser) private {
    _burn(forUser, amount);
    redemptionLookup[forUser] += amount;
  }

  /**
   * @notice Batch function for processing redemptions
   *
   */
  function batchStartRedeem() public {
    require(block.timestamp > vaultMaturity, "Not at maturity");
    require(hasRole(VALT_OPERATOR, msg.sender), "Not a operator");

    for (uint256 i = 0; i < tokenHolders.length; i++) {
      address user = tokenHolders[i];
      uint256 amount = balanceOf(user);
      if (amount > 0) {
        startRedeem(amount, user);
      }
    }
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

  // function markRedeemed(uint256 amount, address account) external {
  //   require(hasRole(VALT_OPERATOR, msg.sender), "Not a operator");
  //   redemptionLookup[account] -= amount;
  // }

  /**
   * @notice Get the stable coins
   * @return All of the stable coins
   *
   */
  function getStableCoins() public view returns (address[] memory) {
    return stableCoins;
  }

  /**
   * @notice Get the token holders
   * @return All of the token holders
   *
   */
  function getTokenHolders() public view returns (address[] memory) {
    return tokenHolders;
  }

  /**
   * @notice Get the whitelisted wallets
   * @return All of the whitelisted wallets
   *
   */
  function getWhitelist() public view returns (address[] memory) {
    return whitelistedWallets;
  }

  /**
   * @notice Adds a stable coin, must be a vault owner
   * @param newToken Add a new token to the redemption pool
   *
   */
  function addToStableCoins(address newToken) public {
    require(hasRole(VALT_OPERATOR, msg.sender), "Not a operator");
    stableCoins.push(newToken);
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
   * @notice Redeem from the destination stable coins reserve
   * @param rewardToken Token they will redeem
   * @param tokenHolder The token holder address
   *
   */
  function redeemFromStableCoin(address rewardToken, address tokenHolder)
    public
  {
    require(block.timestamp > vaultMaturity, "Not at maturity");

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

    for (uint256 p = 0; p < stableCoins.length; p++) {
      address rToken = stableCoins[p];
      if (rewardToken == rToken) {
        ERC20(rToken).approve(tokenHolder, redeemAmount);
        ERC20(rToken).transfer(tokenHolder, redeemAmount);
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
