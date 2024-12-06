import "hardhat/types/config";
import { type HardhatUserConfig } from "hardhat/config";

import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-solhint";

import "tsconfig-paths/register";
import "solidity-coverage";

import * as dotenv from "dotenv";

dotenv.config();

// import "./tasks";

// Testnet ENV
const HAVEN_TESTNET_RPC = process.env.HAVEN_TESTNET_RPC || "";

// See, in general, https://hardhat.org/hardhat-runner/docs/config#configuration
const config: HardhatUserConfig = {
    networks: {
        hardhat: {
            allowUnlimitedContractSize: true,
            forking: {
                enabled: !!HAVEN_TESTNET_RPC,
                url: HAVEN_TESTNET_RPC,
            },
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
                version: "0.5.16",
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
};

export default config;
