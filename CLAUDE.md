# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DebtHook is a DeFi lending protocol that leverages Uniswap v4 hooks for efficient liquidations. The protocol enables collateralized lending with ETH as collateral and USDC as the lending currency, featuring:

- **Smart Contracts**: Solidity contracts using Foundry framework with Uniswap v4 integration
- **Frontend**: Next.js app with TypeScript, shadcn/ui components, and Web3 integration
- **Backend**: Supabase for off-chain order management and indexing
- **Key Innovation**: Liquidations execute directly through Uniswap v4 swaps via hook mechanics

## Project Structure

```
debt-hook/
├── blockchain/          # Smart contract development
│   ├── src/            # Contract source files
│   ├── test/           # Foundry tests
│   └── script/         # Deployment scripts
├── dapp/               # Next.js frontend application (submodule)
│   ├── app/            # App router pages
│   ├── components/     # React components
│   └── lib/            # Utilities and hooks
└── v4-docs/            # Uniswap v4 documentation (submodule)
    └── docs/           # Implementation guides and best practices
```

## Common Commands

### Smart Contract Development
```bash
# Build contracts
forge build

# Run all tests
forge test

# Run specific test
forge test --match-test <testName>

# Format Solidity code
forge fmt

# Gas snapshot
forge snapshot
```

### Frontend Development
```bash
# Start development server
cd dapp && pnpm dev

# Build for production
cd dapp && pnpm build

# Run linter
cd dapp && pnpm lint
```

## Architecture Overview

Read the Protocol Review to understand current status of the protocol (PROTOCOL_REVIEW.md)

### Smart Contract Architecture
The protocol uses two main contracts:

1. **DebtHook** (blockchain/src/DebtHook.sol): Core lending logic integrated as a Uniswap v4 hook
   - Manages collateralized debt positions with ETH collateral and USDC loans
   - Handles loan creation, repayment, and liquidation through Uniswap pools
   - Implements `beforeSwap` and `afterSwap` hooks for liquidation mechanics

2. **DebtOrderBook** (blockchain/src/DebtOrderBook.sol): Off-chain order management
   - Uses EIP-712 signatures for gasless order creation
   - Validates and executes loan orders on-chain
   - Integrates with DebtHook for loan creation

### Frontend Architecture
Next.js app with the following key pages:
- `/market`: Unified marketplace for browsing and accepting loan offers
- `/dashboard`: Portfolio management for active positions (borrower/lender views)

The frontend integrates:
- **Web3 Stack**: Privy for wallet connections, Viem for contract interactions
- **Data Management**: Supabase for off-chain order storage with real-time updates
- **UI Components**: shadcn/ui with Tailwind CSS for consistent design

## Development Workflow

### Phase 1: Contract Development
1. Set up Foundry environment with Uniswap v4 and Chainlink dependencies
2. Implement core contracts (DebtHook, DebtOrderBook)
3. Write comprehensive tests covering all loan scenarios
4. Deploy to testnet with deployment scripts

### Phase 2: Off-chain Infrastructure
1. Set up Supabase database for order management
2. Implement Edge Functions for order validation
3. Create keeper bot for automated liquidations
4. Configure real-time subscriptions for order updates

### Phase 3: Frontend Integration
1. Initialize Next.js app with Privy and Viem
2. Build market interface with order browsing/filtering
3. Implement dashboard with position management
4. Add repayment and liquidation flows
5. Conduct end-to-end testing on testnet

## Key Development Notes

1. **Testing**: Main test file is `blockchain/test/DebtProtocol.t.sol` which tests the complete loan lifecycle

2. **Contract Interfaces**: When modifying contracts, always update the corresponding interface in `IDebtHook.sol`

3. **Order Signatures**: DebtOrderBook uses EIP-712 structured data. The domain separator and type hashes are critical for signature validation

4. **Liquidation Logic**: Liquidations happen through Uniswap v4 swaps. The hook's `beforeSwap` and `afterSwap` functions manage the liquidation process

5. **Frontend Integration**: Key user flows include:
   - Lenders create signed orders (off-chain) stored in Supabase
   - Borrowers browse orders and accept them (on-chain transaction)
   - Dashboard shows positions with real-time updates
   - Repayments require token approval before execution

6. **Environment Variables**: Required for both frontend and contracts:
   - Contract addresses (DebtHook, DebtOrderBook, USDC, WETH)
   - Supabase credentials (URL, anon key)
   - RPC endpoints for target networks

## Git Submodule Management

This project uses git submodules for modular development:

### Submodules
1. **dapp**: Next.js frontend application
2. **v4-docs**: Uniswap v4 documentation for implementation reference

### Common Submodule Commands
```bash
# Clone repository with submodules
git clone --recurse-submodules <repo-url>

# Initialize submodules (if cloned without --recurse-submodules)
git submodule init
git submodule update

# Update all submodules to latest version
git submodule update --remote

# Update specific submodule
git submodule update --remote dapp
git submodule update --remote v4-docs

# Commit submodule changes
git add dapp v4-docs
git commit -m "Update submodules"
```

### V4 Documentation Reference
The v4-docs submodule contains critical implementation guides:
- Hook development best practices
- Pool initialization patterns
- Liquidation mechanism examples
- Security considerations for v4 integration

Always refer to v4-docs when implementing hook functionality to ensure compliance with Uniswap v4 standards.
