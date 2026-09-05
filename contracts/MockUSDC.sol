// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title MockUSDC — Mintable ERC-20 for FreeLock Sepolia testing
contract MockUSDC is ERC20, Ownable {
    uint8 private constant DECIMALS = 6; // USDC uses 6 decimals
    uint256 public constant FAUCET_AMOUNT = 1_000 * 10 ** 6; // 1 000 USDC per mint

    event Minted(address indexed to, uint256 amount);

    constructor() ERC20("Mock USDC", "mUSDC") Ownable(msg.sender) {}

    /// @notice Anyone can mint FAUCET_AMOUNT to themselves (testnet only)
    function mint() external {
        _mint(msg.sender, FAUCET_AMOUNT);
        emit Minted(msg.sender, FAUCET_AMOUNT);
    }

    /// @notice Owner can mint arbitrary amount to any address
    function mintTo(address to, uint256 amount) external onlyOwner {
        require(amount > 0, "Zero amount");
        _mint(to, amount);
        emit Minted(to, amount);
    }

    function decimals() public pure override returns (uint8) { return DECIMALS; }
}
