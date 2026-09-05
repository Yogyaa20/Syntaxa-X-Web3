# FreeLock 🔒

> Trustless freelance payments. Zero fees. Zero middleman.

FreeLock is a decentralized freelance escrow smart contract dApp built for **HACKBLOX 2026**. It allows clients to lock ETH/USDC payments into milestone-based escrow contracts with IPFS proof of work storage, dispute resolution, and on-chain freelancer reputation scores.

---

## 📜 Deployed Smart Contracts (Sepolia Testnet)

- **Escrow Contract (`FreelanceEscrow.sol`)**: [`0xbCf4C61293aC20Bd0cFfC1ce8Acadf6Dff5cb7a4`](https://sepolia.etherscan.io/address/0xbCf4C61293aC20Bd0cFfC1ce8Acadf6Dff5cb7a4)
- **Mock USDC Contract (`MockUSDC.sol`)**: [`0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D`](https://sepolia.etherscan.io/address/0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D)

---

## 🔥 Key Features

1. **Milestone Escrow**: Lock ETH or ERC-20 (USDC) into 2-3 milestone stages per job.
2. **IPFS Proof of Delivery**: Job details and milestone proof hashes are pinned directly to IPFS via Pinata.
3. **On-Chain Reputation**: Freelancer reputation score updates dynamically based on successful deliveries and resolved disputes.
4. **Dispute Resolution**: Built-in arbitration mechanism to handle disputed milestones smoothly.
5. **Etherscan Verification**: Instant deep links to Sepolia block explorer for verified execution.

---

## 🛠️ Tech Stack & Prerequisites

- **Smart Contracts**: Solidity `0.8.34`, Hardhat v3, OpenZeppelin (`ReentrancyGuard`, `Ownable`)
- **Frontend Framework**: Next.js 15 (App Router), React 19, TypeScript
- **Styling**: Tailwind CSS (Dark Mode theme)
- **Web3 Engine**: Wagmi v2, Viem, RainbowKit
- **Storage**: Pinata IPFS API

---

## ⚡ How to Run Locally

### 1. Smart Contracts & Testing

```bash
# Install root dependencies
npm install

# Compile smart contracts
npx hardhat compile

# Run complete test suite (9 test cases)
npx hardhat test
```

### 2. Frontend Setup

```bash
cd frontend

# Install frontend dependencies
npm install

# Set environment variables in frontend/.env.local:
# NEXT_PUBLIC_PINATA_JWT=your_pinata_jwt_here
# NEXT_PUBLIC_MOCK_USDC_ADDRESS=0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D

# Start development server
npm run dev
```

Visit [http://localhost:3000](http://localhost:3000) to access the application.

---

## 👥 Team

**Syntaxa X Web3**
- Hackathon: HACKBLOX 2026
