import "dotenv/config";
import hardhatEthers from "@nomicfoundation/hardhat-ethers";
import hardhatMocha from "@nomicfoundation/hardhat-mocha";
import hardhatChaiMatchers from "@nomicfoundation/hardhat-ethers-chai-matchers";
import { defineConfig } from "hardhat/config";

// Strip leading 0x if present — Hardhat v3 wants a raw hex string
const PRIVATE_KEY: string = (
  process.env.PRIVATE_KEY ??
  "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" // Hardhat default key — local only, NEVER use on mainnet
).replace(/^0x/, "");

const SEPOLIA_RPC_URL: string =
  process.env.SEPOLIA_RPC_URL ??
  "https://ethereum-sepolia-rpc.publicnode.com";

export default defineConfig({
  plugins: [hardhatEthers, hardhatMocha, hardhatChaiMatchers],

  solidity: {
    version: "0.8.34",
    settings: {
      optimizer: { enabled: true, runs: 200 },
    },
  },

  networks: {
    // Local in-process network (Hardhat v3 EDR engine)
    hardhat: {
      type: "edr-simulated",
    },
    // Sepolia testnet
    sepolia: {
      type: "http",
      url: SEPOLIA_RPC_URL,
      accounts: [`0x${PRIVATE_KEY}`],
      chainId: 11155111,
    },
  },

  paths: {
    sources:   "./contracts",
    scripts:   "./scripts",
    tests:     "./test",
    artifacts: "./artifacts",
    cache:     "./cache",
  },
});
