var destManager = artifacts.require("DesinationTokenManager");
var destToken = artifacts.require("DestinationBondToken");

module.exports = function (deployer) {
  // deployment steps
  deployer.deploy(destManager);
  deployer.deploy(
    destToken,
    "",
    "",
    "",
    1,
    "0x8f7DBcC2B17F7696bC738E8f526042b2a176Ad95",
    "1"
  );
};
