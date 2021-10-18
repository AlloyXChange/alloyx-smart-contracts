const ContractKit = require("@celo/contractkit");
const Web3 = require("web3");
const path = require("path");

// Connect to the desired network
const web3 = new Web3("https://alfajores-forno.celo-testnet.org");
const kit = ContractKit.newKitFromWeb3(web3);

const prodWeb3 = new Web3("https://forno.celo.org");
const prodKit = ContractKit.newKitFromWeb3(prodWeb3);
const HDWalletProvider = require("@truffle/hdwallet-provider");
const getAccount = require("./utils/getAccount").getAccount;
const getEthAccount = require("./utils/getAccount").getEthAccount;
const PrivateKeyProvider = require("truffle-privatekey-provider");
let ethPrivateKey;
async function start() {
	ethPrivateKey = await getEthAccount();
	console.log(`ethPrivateKey: ${ethPrivateKey}`);

	await awaitWrapper();
}

async function awaitWrapper() {
	let account = await getAccount();
	console.log(`Celo Account address: ${account.address}`);
	kit.addAccount(account.privateKey);
	prodKit.addAccount(account.privateKey);
}

start();

module.exports = {
	/**
	 * Networks define how you connect to your ethereum client and let you set the
	 * defaults web3 uses to send transactions. If you don't specify one truffle
	 * will spin up a development blockchain for you on port 9545 when you
	 * run `develop` or `test`. You can ask a truffle command to use a specific
	 * network from the command line, e.g
	 *
	 * $ truffle test --network <network-name>
	 */
	contracts_build_directory: path.join(__dirname, "../src/contracts"),
	networks: {
		ropsten: {
			provider: () =>
				new PrivateKeyProvider(
					ethPrivateKey,
					`https://ropsten.infura.io/v3/e12e5799db93421685a9c4af77793f59`
				),
			network_id: 3, // Ropsten's id

			gas: "4201441", // 4M
			// gasPrice: "110000000000", // 20gwei
			gasPrice: "112000000000", // 20gwei
			confirmations: 5, // # of confs to wait between deployments. (default: 0)
			timeoutBlocks: 200, // # of blocks before a deployment times out  (minimum/default: 50)
			skipDryRun: true, // Skip dry run before migrations? (default: false for public nets )
		},

		rinkeby: {
			provider: () =>
				new PrivateKeyProvider(
					ethPrivateKey,
					`https://rinkeby.infura.io/v3/e12e5799db93421685a9c4af77793f59`
				),
			network_id: 4, // Rinkeby's id

			gas: 5500000, // rinkeby has a lower block limit than mainnet
			confirmations: 2, // # of confs to wait between deployments. (default: 0)
			timeoutBlocks: 200, // # of blocks before a deployment times out  (minimum/default: 50)
			skipDryRun: true, // Skip dry run before migrations? (default: false for public nets )
		},
		mainnet_eth: {
			provider: () =>
				new HDWalletProvider(
					ethPrivateKey,
					`https://mainnet.infura.io/v3/e12e5799db93421685a9c4af77793f59`
				),

			// provider: () =>
			// 	new PrivateKeyProvider(
			// 		ethPrivateKey,
			// 		`https://mainnet.infura.io/v3/e12e5799db93421685a9c4af77793f59`
			// 	),
			network_id: 1, // Mainnet's id
			gas: "4601441", // 4M
			// gasPrice: "110000000000", // 20gwei
			gasPrice: "112000000000", // 20gwei

			// gasPrice: 5000000000, // 2 GWei
			// confirmations: 2, // # of confs to wait between deployments. (default: 0)
			// timeoutBlocks: 200, // # of blocks before a deployment times out  (minimum/default: 50)
			skipDryRun: false, // Skip dry run before migrations? (default: false for public nets )
		},
		alfajores: {
			provider: kit.web3.currentProvider,
			network_id: 44787,
		},
		mainnet: {
			provider: prodKit.web3.currentProvider,
			network_id: 42220,
		},
	},

	// Set default mocha options here, use special reporters etc.
	mocha: {
		reporter: "eth-gas-reporter",
	},

	// Configure your compilers
	compilers: {
		solc: {
			version: "0.8.0", // Fetch exact version from solc-bin (default: truffle's version)
			docker: false, // Use "0.5.1" you've installed locally with docker (default: false)
			settings: {
				// See the solidity docs for advice about optimization and evmVersion
				optimizer: {
					enabled: true,
					runs: 1000,
				},
				evmVersion: "byzantium",
			},
		},
	},
	db: {
		enabled: false,
	},
};
