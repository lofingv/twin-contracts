# Twin.fun Contracts

A bonding curve-based marketplace for digital twin shares built on BNB Smart Chain (BSC) and compatible with other EVM networks.

## Overview

Twin.fun enables users to create, buy, and sell keys in digital twins using a bonding curve pricing mechanism. Each digital twin represents a unique entity (person, brand, or concept) with associated metadata and ownership and knowledge. Key prices increase as more keys are purchased, creating a dynamic market for digital twin keys.

## Technology Stack

**Blockchain:** BNB Smart Chain
**Smart Contracts:** Solidity ^0.8.22  
**Development Framework:** Foundry  
**Libraries:** OpenZeppelin Contracts (Upgradeable)  
**Proxy Pattern:** UUPS (Universal Upgradeable Proxy Standard)

## Supported Networks

- BNB Smart Chain Mainnet (Chain ID: 56)

## Contract Addresses

| Network | Core Contract | Notes |
|---------|---------------|-------|
| BNB Mainnet | `0x1e5a5c87513c3a11f763dbce15da60d912b953b3` | Proxy Contract |
| BNB Mainnet | `0x6a898Da0d3B35213Bc07733f8a151F60d80F0dA5` | Implementation |

## Features

**Bonding Curve Pricing:** Share prices follow a mathematical bonding curve formula, where prices increase with supply and decrease when shares are sold.

**Digital Twin Creation:** Users can create new digital twins by purchasing a minimum number of shares and setting associated metadata URLs.

**Buy & Sell Shares:** Trade shares in any digital twin with automatic price calculation based on current supply.

**Fee Structure:** Configurable protocol fees (default 1%) and subject fees (default 1%) that are distributed to the protocol and digital twin owners respectively.

**Upgradeable Contracts:** UUPS proxy pattern allows for contract upgrades while preserving all state and user balances.

**Security Features:** 
- ReentrancyGuard protection on all trading functions
- Access control for administrative functions
- Ownership verification for digital twin management

**Gas Efficient:** Optimized for BNB Smart Chain's low gas costs, making trading affordable for all users.

## Development

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js (for subgraph development)

### Setup

```bash
# Install dependencies
make install

# Build contracts
make build

# Run tests
make test

# Run tests with gas reporting
make test-gas
```

### Deployment

```bash
# Deploy to BSC
make deploy-bsc

# Deploy to local node
make deploy-local
```

See `Makefile` for all available commands.

## Architecture

The contract uses a UUPS upgradeable proxy pattern:
- **Implementation Contract:** `DigitalTwinSharesV1.sol` - Contains the core logic
- **Proxy Contract:** Deployed via Foundry scripts, stores all state
- **Upgrade Authorization:** Only the contract owner can authorize upgrades

### Key Functions

- `createDigitalTwin(bytes16 digitalTwinId, string memory url)` - Create a new digital twin
- `buyShares(bytes16 digitalTwinId, uint256 amount)` - Purchase shares in a digital twin
- `sellShares(bytes16 digitalTwinId, uint256 amount, uint256 minPayout)` - Sell shares back to the curve
- `getBuyPrice(bytes16 digitalTwinId, uint256 amount)` - Get the price to buy shares
- `getSellPrice(bytes16 digitalTwinId, uint256 amount)` - Get the price for selling shares

## Pricing Formula

The bonding curve uses a summation-based pricing formula:
- Price increases quadratically with supply
- Formula: `sum((supply + amount - 1) * (supply + amount) * (2 * (supply + amount - 1) + 1) / 6) - sum((supply - 1) * supply * (2 * (supply - 1) + 1) / 6)`
- Scaled by `1 ether / 50000000` for practical pricing

## Testing

The project includes comprehensive test coverage:
- Access control and authorization tests
- Bonding curve pricing verification
- Reentrancy attack protection
- Edge cases and integration tests
- UUPS upgrade functionality tests

Run tests with:
```bash
forge test -vvv
```

## License

MIT