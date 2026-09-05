import hre from "hardhat";

async function main(): Promise<void> {
  const conn = await hre.network.connect();
  const { ethers } = conn;

  const [deployer] = await ethers.getSigners();
  console.log("Deployer :", deployer.address);
  console.log("Balance  :", ethers.formatEther(
    await ethers.provider.getBalance(deployer.address)
  ), "ETH\n");

  const usdc = await ethers.deployContract("MockUSDC");
  await usdc.waitForDeployment();

  const addr = await usdc.getAddress();
  console.log("✅ MockUSDC deployed!");
  console.log("   Address  :", addr);
  console.log("   Explorer : https://sepolia.etherscan.io/address/" + addr);
  console.log("\n   Add to .env.example:");
  console.log("   NEXT_PUBLIC_MOCK_USDC_ADDRESS=" + addr);
}

main().catch((err) => { console.error(err); process.exitCode = 1; });
