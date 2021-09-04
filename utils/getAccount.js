const Web3 = require("web3");
const fs = require("fs");
const path = require("path");
var web3 = new Web3();

const filePath = path.join(__dirname, "../.secret");
const ethFilePath = path.join(__dirname, "../ethereum.secret");

function getAccount() {
  return new Promise((resolve) => {
    if (fs.existsSync(filePath)) {
      fs.readFile(filePath, { encoding: "utf-8" }, (err, data) => {
        resolve(web3.eth.accounts.privateKeyToAccount(data));
      });
    } else {
      let randomAccount = web3.eth.accounts.create();

      fs.writeFile(filePath, randomAccount.privateKey, (err) => {
        if (err) {
          return console.log(err);
        }
      });

      resolve(randomAccount);
    }
  });
}

async function getEthAccount() {

  return new Promise((resolve) => {
    if (fs.existsSync(ethFilePath)) {
      fs.readFile(ethFilePath, { encoding: "utf-8" }, (err, data) => {

        resolve(data);
      });
    }
  });
}

module.exports = {
  getAccount,
  getEthAccount,
};
