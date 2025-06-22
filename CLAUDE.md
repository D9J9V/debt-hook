# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a DeFi lending protocol that integrates with Uniswap v4 hooks. It consists of:
- Solidity smart contracts using Foundry framework
- Next.js frontend with TypeScript and shadcn/ui components

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
- `/borrow`: Interface for borrowers to accept loan offers
- `/lend`: Interface for lenders to create loan offers
- `/dashboard`: Portfolio management for active positions

The frontend needs Web3 integration (Wagmi + Viem) and will use Supabase for off-chain order storage.

## Key Development Notes

1. **Testing**: Main test file is `blockchain/test/DebtProtocol.t.sol` which tests the complete loan lifecycle

2. **Contract Interfaces**: When modifying contracts, always update the corresponding interface in `IDebtHook.sol`

3. **Order Signatures**: DebtOrderBook uses EIP-712 structured data. The domain separator and type hashes are critical for signature validation

4. **Liquidation Logic**: Liquidations happen through Uniswap v4 swaps. The hook's `beforeSwap` and `afterSwap` functions manage the liquidation process

5. **Frontend Integration**: Refer to `system-prompt.md` for detailed integration steps between frontend and smart contracts

## Git Submodule Management
- Use `git submodule update --remote` to update to the latest version
- Commit changes to the submodule in the main repository when updating