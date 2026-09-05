// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title FreelanceEscrow — FreeLock HACKBLOX 2026
/// @notice Decentralised milestone-based escrow with on-chain reputation.
contract FreelanceEscrow is ReentrancyGuard, Ownable {

    // ─── Constants ───────────────────────────────────────────────────────────
    uint8  public constant MIN_MILESTONES     = 2;
    uint8  public constant MAX_MILESTONES     = 3;
    uint256 public constant REPUTATION_REWARD = 10;
    uint256 public constant REPUTATION_SLASH  = 5;
    uint256 public constant DISPUTE_FEE_BPS   = 100; // 1 % platform fee on disputes

    // ─── Enums ───────────────────────────────────────────────────────────────
    enum MilestoneState { Pending, Delivered, Approved, Disputed, Resolved }

    // ─── Structs ─────────────────────────────────────────────────────────────
    struct Milestone {
        uint256        amount;
        MilestoneState state;
    }

    struct Job {
        address payable client;
        address payable freelancer;
        string          ipfsCid;
        uint8           milestoneCount;
        bool            active;
        mapping(uint8 => Milestone) milestones;
    }

    // ─── State ────────────────────────────────────────────────────────────────
    uint256 public jobCounter;
    mapping(uint256 => Job)     private jobs;
    mapping(address => uint256) public  reputation;

    // ─── Events ──────────────────────────────────────────────────────────────
    event JobCreated(uint256 indexed jobId, address indexed client, address indexed freelancer, string ipfsCid);
    event MilestoneDelivered(uint256 indexed jobId, uint8 indexed milestoneIndex);
    event MilestoneApproved(uint256 indexed jobId, uint8 indexed milestoneIndex, uint256 amount);
    event DisputeRaised(uint256 indexed jobId, uint8 indexed milestoneIndex);
    event DisputeResolved(uint256 indexed jobId, uint8 indexed milestoneIndex, address winner);
    event ReputationUpdated(address indexed freelancer, uint256 newScore);

    // ─── Modifiers ───────────────────────────────────────────────────────────
    modifier onlyClient(uint256 jobId)     { require(msg.sender == jobs[jobId].client,     "Not client");     _; }
    modifier onlyFreelancer(uint256 jobId) { require(msg.sender == jobs[jobId].freelancer, "Not freelancer"); _; }
    modifier jobActive(uint256 jobId)      { require(jobs[jobId].active, "Job inactive");                     _; }
    modifier validMilestone(uint256 jobId, uint8 idx) {
        require(idx < jobs[jobId].milestoneCount, "Bad milestone index");
        _;
    }

    constructor() Ownable(msg.sender) {}

    // ─── Core Functions ───────────────────────────────────────────────────────

    /// @notice Client creates a job by locking ETH split across 2-3 milestones.
    /// @param freelancer Address of the hired freelancer.
    /// @param amounts    Per-milestone ETH amounts; length must be 2 or 3.
    /// @param ipfsCid    IPFS CID of the job brief / deliverable spec.
    function createJob(
        address payable freelancer,
        uint256[] calldata amounts,
        string calldata ipfsCid
    ) external payable nonReentrant {
        uint8 count = uint8(amounts.length);
        require(count >= MIN_MILESTONES && count <= MAX_MILESTONES, "2-3 milestones required");
        require(freelancer != address(0) && freelancer != msg.sender, "Invalid freelancer");
        uint256 total;
        for (uint8 i; i < count; ++i) { require(amounts[i] > 0, "Zero amount"); total += amounts[i]; }
        require(msg.value == total, "ETH mismatch");

        uint256 jobId = ++jobCounter;
        Job storage j = jobs[jobId];
        j.client = payable(msg.sender);
        j.freelancer = freelancer;
        j.ipfsCid = ipfsCid;
        j.milestoneCount = count;
        j.active = true;
        for (uint8 i; i < count; ++i) j.milestones[i] = Milestone(amounts[i], MilestoneState.Pending);

        emit JobCreated(jobId, msg.sender, freelancer, ipfsCid);
    }

    /// @notice Freelancer signals a milestone is ready for review.
    function markDelivered(uint256 jobId, uint8 idx)
        external
        onlyFreelancer(jobId)
        jobActive(jobId)
        validMilestone(jobId, idx)
    {
        Milestone storage m = jobs[jobId].milestones[idx];
        require(m.state == MilestoneState.Pending, "Not pending");
        m.state = MilestoneState.Delivered;
        emit MilestoneDelivered(jobId, idx);
    }

    /// @notice Client approves a delivered milestone; payment is released and reputation rewarded.
    function approveMilestone(uint256 jobId, uint8 idx)
        external
        onlyClient(jobId)
        jobActive(jobId)
        validMilestone(jobId, idx)
        nonReentrant
    {
        Milestone storage m = jobs[jobId].milestones[idx];
        require(m.state == MilestoneState.Delivered, "Not delivered");
        m.state = MilestoneState.Approved;
        address payable fl = jobs[jobId].freelancer;
        uint256 payout = m.amount;
        m.amount = 0;
        _incrementReputation(fl, REPUTATION_REWARD);
        emit MilestoneApproved(jobId, idx, payout);
        _checkJobComplete(jobId);
        (bool ok,) = fl.call{value: payout}("");
        require(ok, "ETH transfer failed");
    }

    /// @notice Client or freelancer raises a dispute on a delivered milestone.
    function raiseDispute(uint256 jobId, uint8 idx)
        external
        jobActive(jobId)
        validMilestone(jobId, idx)
    {
        Job storage j = jobs[jobId];
        require(msg.sender == j.client || msg.sender == j.freelancer, "Not a party");
        Milestone storage m = j.milestones[idx];
        require(m.state == MilestoneState.Delivered || m.state == MilestoneState.Pending, "Not disputable");
        m.state = MilestoneState.Disputed;
        emit DisputeRaised(jobId, idx);
    }

    /// @notice Owner resolves a dispute and releases funds to the winning party.
    /// @param winner Address of the party that should receive the milestone funds.
    function resolveDispute(uint256 jobId, uint8 idx, address payable winner)
        external
        onlyOwner
        jobActive(jobId)
        validMilestone(jobId, idx)
        nonReentrant
    {
        Job storage j = jobs[jobId];
        require(winner == j.client || winner == j.freelancer, "Invalid winner");
        Milestone storage m = j.milestones[idx];
        require(m.state == MilestoneState.Disputed, "Not disputed");
        m.state = MilestoneState.Resolved;
        uint256 fee    = (m.amount * DISPUTE_FEE_BPS) / 10_000;
        uint256 payout = m.amount - fee;
        m.amount = 0;
        address loser  = (winner == j.freelancer) ? j.client : j.freelancer;
        _decrementReputation(loser, REPUTATION_SLASH);
        emit DisputeResolved(jobId, idx, winner);
        _checkJobComplete(jobId);
        (bool feeOk,) = payable(owner()).call{value: fee}("");
        require(feeOk, "Fee transfer failed");
        (bool payOk,) = winner.call{value: payout}("");
        require(payOk, "Payout transfer failed");
    }

    // ─── Read Helpers ─────────────────────────────────────────────────────────

    /// @notice Returns metadata for a job.
    function getJob(uint256 jobId) external view returns (
        address client, address freelancer, string memory ipfsCid, uint8 milestoneCount, bool active
    ) {
        Job storage j = jobs[jobId];
        return (j.client, j.freelancer, j.ipfsCid, j.milestoneCount, j.active);
    }

    /// @notice Returns the state and locked amount for a single milestone.
    function getMilestone(uint256 jobId, uint8 idx)
        external view validMilestone(jobId, idx)
        returns (uint256 amount, MilestoneState state)
    {
        Milestone storage m = jobs[jobId].milestones[idx];
        return (m.amount, m.state);
    }

    // ─── Internal Helpers ─────────────────────────────────────────────────────

    /// @dev Marks the job inactive once every milestone is Approved or Resolved.
    function _checkJobComplete(uint256 jobId) internal {
        Job storage j = jobs[jobId];
        for (uint8 i; i < j.milestoneCount; ++i) {
            MilestoneState s = j.milestones[i].state;
            if (s != MilestoneState.Approved && s != MilestoneState.Resolved) return;
        }
        j.active = false;
    }

    function _incrementReputation(address freelancer, uint256 delta) internal {
        reputation[freelancer] += delta;
        emit ReputationUpdated(freelancer, reputation[freelancer]);
    }

    function _decrementReputation(address account, uint256 delta) internal {
        reputation[account] = reputation[account] > delta ? reputation[account] - delta : 0;
        emit ReputationUpdated(account, reputation[account]);
    }
}
