import "hardhat/types/config";
import { type HardhatUserConfig } from "hardhat/config";

import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-solhint";
import "hardhat-contract-sizer";
import "@openzeppelin/hardhat-upgrades";
import "solidity-docgen";

import "tsconfig-paths/register";

import * as dotenv from "dotenv";

dotenv.config();

// testnet env
const HAVEN_TESTNET_RPC = process.env.HAVEN_TESTNET_RPC || "";
const TESTNET_CHAIN_ID = +process.env.TESTNET_CHAIN_ID!;
const TESTNET_DEPLOYER = process.env.TESTNET_DEPLOYER || "";
const TESTNET_EXPLORER = process.env.TESTNET_EXPLORER || "";
const TESTNET_EXPLORER_API = process.env.TESTNET_EXPLORER_API || "";
const TESTNET_EXPLORER_API_KEY = process.env.TESTNET_EXPLORER_API_KEY || "";

// devnet env
const DEVNET_CHAIN_ID = +process.env.DEVNET_CHAIN_ID!;
const HAVEN_DEVNET_RPC = process.env.HAVEN_DEVNET_RPC || "";
const DEVNET_DEPLOYER = process.env.DEVNET_DEPLOYER || "";
const DEVNET_VALIDATOR = process.env.DEVNET_VALIDATOR || "";
const DEVNET_EXPLORER = process.env.DEVNET_EXPLORER || "";
const DEVNET_EXPLORER_API = process.env.DEVNET_EXPLORER_API || "";
const DEVNET_EXPLORER_API_KEY = process.env.DEVNET_EXPLORER_API_KEY || "";

// sepolia env
const SEPOLIA_RPC = process.env.SEPOLIA_RPC || "";
const SEPOLIA_DEPLOYER = process.env.SEPOLIA_DEPLOYER || "";
const SEPOLIA_EXPLORER_API_KEY = process.env.SEPOLIA_EXPLORER_API_KEY || "";

// type ext
declare module "hardhat/types/config" {
    interface NetworksUserConfig {
        haven_testnet?: NetworkUserConfig;
        haven_devnet?: NetworkUserConfig;
        sepolia?: NetworkUserConfig;
    }
}

// See, in general, https://hardhat.org/hardhat-runner/docs/config#configuration
const config: HardhatUserConfig = {
    networks: {
        hardhat: {
            forking: {
                enabled: !!HAVEN_TESTNET_RPC,
                url: HAVEN_TESTNET_RPC,
            },
            allowUnlimitedContractSize: true,
        },
        remoteHardhat: {
            url: "http://hardhat:8545",
            forking: {
                enabled: !!HAVEN_TESTNET_RPC,
                url: HAVEN_TESTNET_RPC,
            },
        },
    },
    solidity: {
        compilers: [
            {
                version: "0.8.19",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                        details: { yul: true },
                    },
                },
            },
            {
                version: "0.7.0",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
            {
                version: "0.6.0",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
            {
                version: "0.5.0",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
            {
                version: "0.4.18",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
            {
                version: "0.5.3",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
        ],
    },
    gasReporter: {
        enabled: true,
        outputFile: "gas-report.txt",
        noColors: true,
    },
    mocha: {
        timeout: 40_000,
    },
    contractSizer: {
        // see: https://github.com/ItsNickBarry/hardhat-contract-sizer
        alphaSort: false,
        disambiguatePaths: false,
        runOnCompile: false,
        strict: true,
    },
    docgen: {
        // see: https://github.com/OpenZeppelin/solidity-docgen#readme
        outputDir: "./docs",
        pages: "files",
        exclude: [
            "test",
            "utils/test",
            "fee/test",
            "fee/prev-versions",
            "h1-native-application/downgrades/v6/test",
            "h1-native-application/downgrades/v7/test",
            "h1-native-application/test",
            "governance/test",
            "tokens/test",
            "proof-of-identity/test",
            "proof-of-identity/examples",
            "proof-of-identity/interfaces/vendor",
            "spotlights/libraries",
            "staking/test",
            "h1-developed-application/test",
            "network-guardian/test",
        ],
    },
    etherscan: {
        apiKey: {
            haven_testnet: TESTNET_EXPLORER_API_KEY,
            haven_devnet: DEVNET_EXPLORER_API_KEY,
            sepolia: SEPOLIA_EXPLORER_API_KEY,
        },
        customChains: [
            {
                network: "haven_testnet",
                chainId: TESTNET_CHAIN_ID,
                urls: {
                    apiURL: TESTNET_EXPLORER_API,
                    browserURL: TESTNET_EXPLORER,
                },
            },
            {
                network: "haven_devnet",
                chainId: DEVNET_CHAIN_ID,
                urls: {
                    apiURL: DEVNET_EXPLORER_API,
                    browserURL: DEVNET_EXPLORER,
                },
            },
        ],
    },
};

if (HAVEN_TESTNET_RPC && TESTNET_DEPLOYER && config.networks) {
    config.networks = {
        ...config.networks,
        haven_testnet: {
            url: HAVEN_TESTNET_RPC,
            accounts: [TESTNET_DEPLOYER],
        },
    };
}

if (
    HAVEN_DEVNET_RPC &&
    DEVNET_DEPLOYER &&
    DEVNET_VALIDATOR &&
    config.networks
) {
    config.networks = {
        ...config.networks,
        haven_devnet: {
            url: HAVEN_DEVNET_RPC,
            accounts: [DEVNET_DEPLOYER, DEVNET_VALIDATOR],
        },
    };
}

if (SEPOLIA_RPC && SEPOLIA_DEPLOYER && config.networks) {
    config.networks = {
        ...config.networks,
        sepolia: {
            url: SEPOLIA_RPC,
            accounts: [SEPOLIA_DEPLOYER],
        },
    };
}

export default config;
