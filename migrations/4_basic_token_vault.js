const SimpleToken = artifacts.require("BondToken.sol");
const TokenReceiver = artifacts.require("TokenVault");

module.exports = async function (deployer) {
  await deployer.deploy(SimpleToken);
  const token = await SimpleToken.deployed();
  await deployer.deploy(TokenReceiver, token.address);
};
