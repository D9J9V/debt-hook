# DebtHook Smart Contracts

Core smart contracts for the DebtHook protocol - a Uniswap V4 hook implementation enabling automated liquidations within swap transactions.

## Overview

DebtHook is a collateralized lending protocol that revolutionizes liquidations by integrating directly with Uniswap V4:
- Borrowers deposit ETH collateral to borrow USDC at fixed rates
- Lenders create signed loan offers off-chain (gasless via EIP-712)
- Liquidations execute automatically during ETH/USDC swaps
- The protocol operates as a true V4 hook with beforeSwap/afterSwap callbacks

## Current Status (June 26, 2025)

✅ **Phase A: V4 Hook Implementation** - DEPLOYED to Unichain Sepolia
✅ **Phase C: EigenLayer AVS** - DEPLOYED to Ethereum Sepolia with operator running
🚧 **Phase B: USDC Paymaster** - Planned next enhancement

## Key Features

- **V4 Hook Integration**: Liquidations execute within normal swap transactions
- **Gasless Orders**: Lenders sign loan offers off-chain
- **MEV Protection**: Atomic liquidations prevent frontrunning
- **Chainlink Price Feeds**: Real-time ETH/USD pricing
- **Capital Efficiency**: No dedicated liquidator bots needed
- **EigenLayer AVS**: Decentralized operator network for batch loan matching
- **Operator Authorization**: Only authorized operators can create batch loans

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

#### Quick Deployment (Recommended)
```bash
# Set environment variables
export PRIVATE_KEY="your-private-key"
export RPC_URL="https://unichain-sepolia-rpc.publicnode.com"
export TREASURY="your-treasury-address" # Optional, defaults to deployer

# Deploy with automatic hook mining
forge script script/DeployHookOptimized.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

This script automatically:
- Mines an address with correct permission bits (0xC8)
- Deploys all contracts in the correct order
- Handles circular dependencies
- Outputs deployment addresses for frontend configuration

#### Alternative Deployment Options

**Option 1: Detailed Deployment with Logging**
```bash
forge script script/DeployHook.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  -vvvv
```

**Option 2: Quick Testing (No Hook Mining)**
```bash
# WARNING: Only for testing, won't work with V4 validation
forge script script/DeploySimple.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```

#### Test Hook Mining Locally
```bash
# Verify hook mining works before deployment
forge script script/TestHookMining.s.sol
```

#### Step 3: Post-Deployment Setup
1. Initialize the ETH/USDC pool in Uniswap V4
2. Register the hook with PoolManager
3. Update frontend with deployed addresses
4. Test basic loan flow

### Deployed Addresses (Unichain Sepolia)
```
DebtHook: 0x49e39eFDE0C93F6601d84cb5C6D24c1B23eB00C8 (with operator authorization)
DebtOrderBook: 0xce060483D67b054cACE5c90001992085b46b4f66
PoolManager: 0x1d933AB5bdE2b087a28e24A8E5d4DF77021CFEcC
ChainlinkPriceFeed: 0x3333Bc77EdF180D81ff911d439F02Db9e34e8603
USDC: 0x73CFC55f831b5DD6E5Ee4CEF02E8c05be3F069F6
WETH: Native ETH (address(0))
```

### EigenLayer AVS (Ethereum Sepolia)
```
ServiceManager: 0x3333Bc77EdF180D81ff911d439F02Db9e34e8603
StakeRegistry: 0x3Df55660F015689174cd42F2FF7D2e36564404b5
Operator: 0x2f131a86C5CB54685f0E940B920c54E152a44B02 (authorized)
```

## Hook Permissions

DebtHook requires specific permission bits in its address:
- Bit 7: `BEFORE_SWAP_FLAG` (0x80)
- Bit 6: `AFTER_SWAP_FLAG` (0x40)
- Bit 3: `BEFORE_SWAP_RETURNS_DELTA_FLAG` (0x08)

Combined: The address must have `0xC8` in its permission bits.

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