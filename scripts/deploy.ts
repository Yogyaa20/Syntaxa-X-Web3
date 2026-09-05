import hre from "hardhat";

async function main(): Promise<void> {
  const conn = await hre.network.connect();
  const { ethers } = conn;

  const [deployer] = await ethers.getSigners();
  console.log("Deployer :", deployer.address);
  console.log("Balance  :", ethers.formatEther(
    await ethers.provider.getBalance(deployer.address)
  ), "ETH\n");

  const escrow = await ethers.deployContract("FreelanceEscrow");
  await escrow.waitForDeployment();

  const addr = await escrow.getAddress();
  console.log("✅ FreelanceEscrow deployed!");
  console.log("   Address  :", addr);
  console.log("   Explorer : https://sepolia.etherscan.io/address/" + addr);
}

main().catch((err) => { console.error(err); process.exitCode = 1; });
