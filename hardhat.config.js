require("@nomicfoundation/hardhat-ignition");
require("@typechain/hardhat");
require("dotenv").config();
require("@nomicfoundation/hardhat-toolbox");
require("hardhat-gas-reporter");
require("solidity-coverage");

// const { exportContractArtifacts } = require("./scripts/exportArtifacts");

const MAINNET_RPC_URL = process.env.MAINNET_RPC_URL || "http://localhost:8545";
const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL || "http://localhost:8545";
const SEPOLIA_PRIV_KEY = process.env.SEPOLIA_PRIV_KEY || "0x";
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "YOUR_ETHERSCAN_API_KEY";
const COINMARKETCAP_API_KEY = process.env.COINMARKETCAP_API_KEY || "YOUR_COINMARKETCAP_API_KEY";

/* task("export", "Export the contract abis")
    .addParam("chainId", "The target chain ID")
    .addParam("dir", "The destination dir of the export")
    .setAction(async (taskArgs) => {
        await exportContractArtifacts(taskArgs);
    }); */

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    solidity: {
        compilers: [
            {
                version: "0.8.10",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 100
                    },
                    viaIR: true
                }
            },
            {
                version: "0.8.19",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 100
                    },
                    viaIR: true
                }
            },
            {
                version: "0.8.27",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 100
                    },
                    viaIR: true
                }
            },
            {
                version: "0.7.5",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 100
                    },
                    viaIR: true
                }
            }
        ]
    },
    networks: {
        hardhat: {
            chainId: 31337,
            forking: {
                url: MAINNET_RPC_URL,
                blockNumber: 22851531
            }
        },
        localhost: {
            chainId: 31337,
            forking: {
                url: MAINNET_RPC_URL,
                blockNumber: 22851531
            },
            ignition: {
                blockPollingInterval: 1_000,
                requiredConfirmations: 1
            }
        },
        sepolia: {
            url: SEPOLIA_RPC_URL,
            accounts: [SEPOLIA_PRIV_KEY],
            chainId: 11155111,
            ignition: {
                blockPollingInterval: 1_000,
                requiredConfirmations: 1
            }
        }
    },
    typechain: {
        outDir: "typechain",
        target: "ethers-v6",
        alwaysGenerateOverloads: true,
        dontOverrideCompile: false
    },
    etherscan: {
        apiKey: ETHERSCAN_API_KEY
    },
    gasReporter: {
        enabled: true,
        outputFile: "./test-reports/gas-report.txt",
        noColors: true,
        currency: "USD"
        // coinmarketcap: COINMARKETCAP_API_KEY,
    },
    mocha: {
        timeout: 300_000
    }
};
