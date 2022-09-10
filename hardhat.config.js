require("@nomicfoundation/hardhat-toolbox");

const ALCHEMY_API_KEY = "3jGJb0W4dFSw3iupkDFQcLCOVuf0drGr";
const GOERLI_PRIVATE_KEY =
	"72bd94376b6fe7c41d71eb1acc0fdfd802a72b7f9e0ec40b887987a1dd794aa9";

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
	solidity: "0.8.9",
	networks: {
		goerli: {
			url: `https://eth-goerli.alchemyapi.io/v2/${ALCHEMY_API_KEY}`,
			accounts: [GOERLI_PRIVATE_KEY],
		},
	},
};
