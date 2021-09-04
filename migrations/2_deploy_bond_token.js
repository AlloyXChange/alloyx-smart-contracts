var bondToken = artifacts.require("BondToken");

module.exports = function (deployer) {
  // deployment steps
  deployer.deploy(bondToken);
};
