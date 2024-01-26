require("dotenv").config();
require("@nomicfoundation/hardhat-ethers");
require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-chai-matchers");
require("hardhat-gas-reporter");

const providerUrl = process.env.INFURA_POLYGON_URL;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.20",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
            details: {
              yul: false,
            },
          },
          viaIR: false,
        },
      },
      {
        version: "0.7.5",
        settings: {},
      },
    ],
    overrides: {
      "node_modules/@uniswap/v3-core/contracts/libraries/FullMath.sol": {
        version: "0.7.5",
        settings: {},
      },
      // 'contracts/libraries/OracleLibrary.sol': {
      //     version: '0.7.8',
      //     settings: {},
      // },
      // 'contracts/libraries/TickMath.sol': {
      //     version: '0.7.8',
      //     settings: {},
      // },
    },
  },
  networks: {
    hardhat: {
      chainId: 31337,
      forking: {
        url: providerUrl,
      },
    },
    ganache: {
      url: "HTTP://127.0.0.1:7545",
      chainId: 1337,
      forking: {
        url: providerUrl,
      },
    },
  },
  gasReporter: {
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    currency: "USD",
    enabled: true,
  },
};
