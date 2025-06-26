# DebtHook Smart Contracts

A DeFi lending protocol built as a Uniswap V4 hook, enabling efficient liquidations through automated swap integration.

## Overview

DebtHook is a collateralized lending protocol where:
- Users can borrow USDC against ETH collateral
- Lenders create signed loan offers (gasless via EIP-712)
- Liquidations happen automatically during Uniswap swaps
- The protocol functions as a true V4 hook with beforeSwap/afterSwap callbacks

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

## Deployment

### Local Development

```bash
# Start local Anvil chain
anvil

# Deploy contracts
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast
```

### Testnet Deployment

The deployment process for V4 hooks requires address mining:

1. **Mine Hook Address**: Find a salt that produces an address with correct permission bits
2. **Deploy with CREATE2**: Use the mined salt to deploy to the predetermined address
3. **Verify Permissions**: Ensure the deployed address has beforeSwap/afterSwap enabled

```bash
# Deploy to Unichain Sepolia
forge script script/DeployHook.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
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