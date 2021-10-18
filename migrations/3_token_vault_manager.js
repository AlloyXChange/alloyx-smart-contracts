var tokenVaultMgr = artifacts.require("TokenVaultFactory");

module.exports = function (deployer) {
	// deployment steps
	deployer.deploy(tokenVaultMgr);
};
