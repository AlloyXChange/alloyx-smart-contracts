var baseToken = artifacts.require("ERC20");

module.exports = function (deployer) {
  // deployment steps
  deployer.deploy(baseToken, "Basic", "TKN");
};
