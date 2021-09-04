var tokenVaultMgr = artifacts.require("TokenVaultManager");

module.exports = function (deployer) {
  // deployment steps
  deployer.deploy(tokenVaultMgr);
};
