import { expect } from "chai";
import { network } from "hardhat";

// Hardhat v3: top-level await — network.create() gives an isolated EDR instance
const { ethers } = await network.create();

// ─── Constants matching FreelanceEscrow ────────────────────────────────────
const M1 = ethers.parseEther("0.05");
const M2 = ethers.parseEther("0.05");
const M3 = ethers.parseEther("0.05");
const AMOUNTS = [M1, M2, M3];
const TOTAL   = M1 + M2 + M3;
const CID     = "QmTestCID";

// ─── Helpers ────────────────────────────────────────────────────────────────
async function deploy() {
  const [owner, client, freelancer, other] = await ethers.getSigners();
  const Escrow = await ethers.getContractFactory("FreelanceEscrow");
  const escrow = await Escrow.deploy();
  return { escrow, owner, client, freelancer, other };
}

async function createJob(escrow: Awaited<ReturnType<typeof deploy>>["escrow"], client: Awaited<ReturnType<typeof deploy>>["client"], freelancer: Awaited<ReturnType<typeof deploy>>["freelancer"]) {
  return escrow.connect(client).createJob(freelancer.address, AMOUNTS, CID, { value: TOTAL });
}

// ─── Test Suite ──────────────────────────────────────────────────────────────
describe("FreelanceEscrow", () => {

  // 1. createJob — locks ETH in contract
  it("createJob: locks correct ETH in contract", async () => {
    const { escrow, client, freelancer } = await deploy();
    await createJob(escrow, client, freelancer);
    expect(await ethers.provider.getBalance(escrow.target)).to.equal(TOTAL);
  });

  // 2. createJob — emits JobCreated
  it("createJob: emits JobCreated event", async () => {
    const { escrow, client, freelancer } = await deploy();
    await expect(createJob(escrow, client, freelancer))
      .to.emit(escrow, "JobCreated")
      .withArgs(1n, client.address, freelancer.address, CID);
  });

  // 3. markDelivered — freelancer can call
  it("markDelivered: freelancer can mark milestone delivered", async () => {
    const { escrow, client, freelancer } = await deploy();
    await createJob(escrow, client, freelancer);
    await expect(escrow.connect(freelancer).markDelivered(1n, 0))
      .to.emit(escrow, "MilestoneDelivered").withArgs(1n, 0);
  });

  // 4. markDelivered — reverts if called by client
  it("markDelivered: reverts when called by client", async () => {
    const { escrow, client, freelancer } = await deploy();
    await createJob(escrow, client, freelancer);
    await expect(escrow.connect(client).markDelivered(1n, 0))
      .to.be.revertedWith("Not freelancer");
  });

  // 5. approveMilestone — only client can call
  it("approveMilestone: reverts when called by non-client", async () => {
    const { escrow, client, freelancer } = await deploy();
    await createJob(escrow, client, freelancer);
    await escrow.connect(freelancer).markDelivered(1n, 0);
    await expect(escrow.connect(freelancer).approveMilestone(1n, 0))
      .to.be.revertedWith("Not client");
  });

  // 6. approveMilestone — transfers correct ETH to freelancer
  it("approveMilestone: sends milestone ETH to freelancer", async () => {
    const { escrow, client, freelancer } = await deploy();
    await createJob(escrow, client, freelancer);
    await escrow.connect(freelancer).markDelivered(1n, 0);
    const balBefore = await ethers.provider.getBalance(freelancer.address);
    await escrow.connect(client).approveMilestone(1n, 0);
    const balAfter = await ethers.provider.getBalance(freelancer.address);
    expect(balAfter - balBefore).to.equal(M1);
  });

  // 7. raiseDispute — blocks approveMilestone
  it("raiseDispute: blocks approval after dispute raised", async () => {
    const { escrow, client, freelancer } = await deploy();
    await createJob(escrow, client, freelancer);
    await escrow.connect(freelancer).markDelivered(1n, 0);
    await escrow.connect(client).raiseDispute(1n, 0);
    await expect(escrow.connect(client).approveMilestone(1n, 0))
      .to.be.revertedWith("Not delivered");
  });

  // 8. resolveDispute — sends funds to winner
  it("resolveDispute: pays correct winner", async () => {
    const { escrow, owner, client, freelancer } = await deploy();
    await createJob(escrow, client, freelancer);
    await escrow.connect(freelancer).markDelivered(1n, 0);
    await escrow.connect(client).raiseDispute(1n, 0);
    const balBefore = await ethers.provider.getBalance(freelancer.address);
    await escrow.connect(owner).resolveDispute(1n, 0, freelancer.address);
    const balAfter = await ethers.provider.getBalance(freelancer.address);
    expect(balAfter - balBefore).to.equal(M1 * 9900n / 10000n);
  });

  // 9. reputation — increases after milestone approval
  it("reputation: increments after successful milestone", async () => {
    const { escrow, client, freelancer } = await deploy();
    await createJob(escrow, client, freelancer);
    await escrow.connect(freelancer).markDelivered(1n, 0);
    await escrow.connect(client).approveMilestone(1n, 0);
    expect(await escrow.reputation(freelancer.address)).to.equal(10n); // REPUTATION_REWARD
  });
});
