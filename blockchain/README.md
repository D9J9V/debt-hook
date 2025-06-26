# DebtHook Smart Contracts

Core smart contracts for the DebtHook protocol - a Uniswap V4 hook implementation enabling automated liquidations within swap transactions.

## Overview

DebtHook is a collateralized lending protocol that revolutionizes liquidations by integrating directly with Uniswap V4:
- Borrowers deposit ETH collateral to borrow USDC at fixed rates
- Lenders create signed loan offers off-chain (gasless via EIP-712)
- Liquidations execute automatically during ETH/USDC swaps
- The protocol operates as a true V4 hook with beforeSwap/afterSwap callbacks

## Current Status

✅ **Phase A: V4 Hook Implementation** - Complete and ready for testnet deployment
🚧 **Phase B: USDC Paymaster** - Planned next enhancement
🔮 **Phase C: Eigenlayer AVS** - Future decentralization upgrade

## Key Features

- **V4 Hook Integration**: Liquidations execute within normal swap transactions
- **Gasless Orders**: Lenders sign loan offers off-chain
- **MEV Protection**: Atomic liquidations prevent frontrunning
- **Chainlink Price Feeds**: Real-time ETH/USD pricing
- **Capital Efficiency**: No dedicated liquidator bots needed

## Architecture

### Core Contracts

1. **DebtHook.sol**
   - Main protocol logic as a Uniswap V4 hook
   - Manages loans: creation, repayment, liquidation
   - Implements beforeSwap/afterSwap for automatic liquidations
   - Must be deployed to specific address (with hook permission bits)

2. **DebtOrderBook.sol**
   - Handles EIP-712 signed loan orders
   - Validates signatures and executes loans
   - Integrates with DebtHook for loan creation

3. **ChainlinkPriceFeed.sol**
   - Wrapper for Chainlink price oracle
   - Provides ETH/USD price with staleness protection
   - Implements IPriceFeed interface

## Installation

```bash
# Clone the repository
git clone <repo-url>
cd debt-hook/blockchain

# Install dependencies
forge install

# Build contracts
forge build
```

## Testing

```bash
# Run all tests
forge test

# Run with gas reporting
forge test --gas-report

# Run specific test
forge test --match-test testLiquidation

# Run fork tests (requires RPC)
forge test --fork-url https://unichain-sepolia-rpc.publicnode.com
```

## Deployment Guide

### Prerequisites
- Foundry installed and configured
- Access to Unichain Sepolia RPC
- Funded wallet for deployment

### Local Development

```bash
# Start local Anvil chain with Unichain Sepolia fork
anvil --fork-url https://sepolia.unichain.org

# Deploy all contracts locally
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

### Unichain Sepolia Deployment

The V4 hook deployment requires careful address mining to ensure proper permissions:

#### Step 1: Mine Hook Address
```bash
# This finds a salt that produces an address with bits 6 & 7 set (0xC0)
forge script script/MineHookAddress.s.sol
```

#### Step 2: Deploy Contracts
```bash
# Set environment variables
export RPC_URL="https://sepolia.unichain.org"
export PRIVATE_KEY="your-private-key"
export ETHERSCAN_API_KEY="your-api-key"

# Deploy all contracts
forge script script/Deploy.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --verifier blockscout \
  --verifier-url https://sepolia.uniscan.xyz/api
```

#### Step 3: Post-Deployment Setup
1. Initialize the ETH/USDC pool in Uniswap V4
2. Register the hook with PoolManager
3. Update frontend with deployed addresses
4. Test basic loan flow

### Deployed Addresses (Unichain Sepolia)
```
ChainlinkPriceFeed: [TO BE DEPLOYED]
DebtHook: [TO BE DEPLOYED]
DebtOrderBook: [TO BE DEPLOYED]
USDC: [TO BE DEPLOYED]
WETH: [TO BE DEPLOYED]
```

## Hook Permissions

DebtHook requires specific permission bits in its address:
- Bit 7: `BEFORE_SWAP_FLAG` (0x80)
- Bit 6: `AFTER_SWAP_FLAG` (0x40)

Combined: The address must have `0xC0` in the last byte.

## Liquidation Mechanics

1. **Detection**: During any swap in the ETH/USDC pool, beforeSwap checks for liquidatable loans
2. **Execution**: If found, the swap amount is modified to include liquidation
3. **Settlement**: afterSwap distributes the proceeds and updates loan state

This design ensures:
- Liquidations happen instantly when needed
- No separate liquidation transactions
- MEV bots cannot frontrun liquidations
- Gas costs are shared with the swap

## Configuration

Key parameters in DebtHook:
- `LIQUIDATION_THRESHOLD`: 150% (health factor < 1.5 triggers liquidation)
- `LIQUIDATION_PENALTY`: 5% (goes to treasury)
- `GRACE_PERIOD`: 24 hours after loan maturity

## Security Considerations

- All external calls use checks-effects-interactions pattern
- Signature replay protection via nonces
- Price oracle manipulation protection (staleness checks)
- Hook permissions validated at deployment
- Reentrancy guards on state-changing functions

## Gas Optimization

- Uses transient storage for temporary liquidation data
- Efficient storage packing in Loan struct
- Custom errors instead of revert strings
- Batch operations where possible

## License

MIT