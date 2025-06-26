# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DebtHook is a DeFi lending protocol that leverages Uniswap v4 hooks for efficient liquidations. The protocol enables collateralized lending with ETH as collateral and USDC as the lending currency, featuring:

- **Smart Contracts**: Solidity contracts using Foundry framework with Uniswap v4 integration
- **Frontend**: Next.js app with TypeScript, shadcn/ui components, and Web3 integration
- **Backend**: Supabase for off-chain order management and indexing
- **Key Innovation**: Liquidations execute directly through Uniswap v4 swaps via hook mechanics

## Implementation Priorities

### Phase A: Uniswap V4 Hook (Current Focus) ✅
**Status**: Core implementation complete, needs testing and deployment
- True V4 hook with beforeSwap/afterSwap callbacks
- Automatic liquidations during ETH/USDC swaps
- MEV-protected atomic liquidation execution
- Deployment target: Unichain Sepolia

### Phase B: USDC Paymaster (Future Enhancement)
**Goal**: Enable gas-free interactions for users paying only with USDC
- EIP-4337 account abstraction integration
- Paymaster contract to sponsor gas fees
- Accept USDC payment for transaction costs
- Seamless UX for non-ETH holders

### Phase C: Eigenlayer Integration (Advanced Feature)
**Goal**: Verifiable and decentralized orderbook
- Eigenlayer AVS for orderbook validation
- Cryptographic proofs for order integrity
- Slashing for malicious orderbook operators
- Enhanced trust and decentralization

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
   - **True V4 Hook**: Implements `beforeSwap` and `afterSwap` callbacks for automatic liquidations
   - **Hook Address**: Must be deployed to an address with specific permission flags encoded (bits 6 & 7 set)
   - **Liquidation Mechanics**:
     - `beforeSwap`: Scans for liquidatable positions when swaps occur in the ETH/USDC pool
     - `afterSwap`: Executes liquidation by selling collateral and distributing proceeds
     - Liquidations are atomic with swaps, providing MEV protection and gas efficiency

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

## V4 Hook Implementation Details

### Hook Permissions and Address Mining
DebtHook must be deployed to an address with specific permission bits set:
- **Bit 7 (BEFORE_SWAP_FLAG)**: Enables `beforeSwap` callback
- **Bit 6 (AFTER_SWAP_FLAG)**: Enables `afterSwap` callback

The deployment process requires:
1. Use `HookMiner` to find a salt that produces an address with bits 6 & 7 set
2. Deploy using CREATE2 with the mined salt
3. Verify the deployed address matches expected permissions

### Liquidation Flow via Hooks

1. **Normal Swap Initiated**: User swaps in the ETH/USDC pool
2. **beforeSwap Hook**:
   - Checks if any loans are liquidatable (health factor < 1.5)
   - If found, calculates collateral to liquidate
   - Returns `BeforeSwapDelta` to modify swap amounts
   - Stores liquidation data in transient storage
3. **Swap Execution**: Uniswap processes the modified swap
4. **afterSwap Hook**:
   - Retrieves liquidation data from transient storage
   - Distributes USDC proceeds to lender
   - Sends penalty (5%) to treasury
   - Returns remaining collateral to borrower
   - Updates loan status to liquidated

### Gas Optimization
- Uses transient storage (TSTORE/TLOAD) for temporary liquidation data
- Liquidations piggyback on existing swaps, no separate transactions
- Batch liquidations possible in a single swap

## Deployment Notes

### Target Network: Unichain Sepolia
- Chain ID: 1301
- RPC: https://sepolia.unichain.org
- Explorer: https://sepolia.uniscan.xyz
- Chainlink ETH/USD price feed: 0xd9c93081210dFc33326B2af4C2c11848095E6a9a

### Deployment Checklist
1. **Pre-deployment**:
   - [ ] Run all tests with `forge test`
   - [ ] Check gas consumption with `forge test --gas-report`
   - [ ] Verify hook address has correct permission bits
   - [ ] Update deployment scripts with correct addresses

2. **Deployment**:
   - [ ] Deploy ChainlinkPriceFeed wrapper
   - [ ] Mine hook address with HookMiner
   - [ ] Deploy DebtHook to mined address
   - [ ] Deploy DebtOrderBook
   - [ ] Initialize pool in Uniswap V4
   - [ ] Register hook with PoolManager

3. **Post-deployment**:
   - [ ] Verify all contracts on explorer
   - [ ] Update frontend environment variables
   - [ ] Test basic loan flow on testnet
   - [ ] Set up monitoring and alerts

## Development Best Practices

### When Working on Contracts
1. Always run tests before committing: `forge test`
2. Format code with: `forge fmt`
3. Update interfaces when modifying external functions
4. Document complex logic with inline comments
5. Consider gas optimization for frequently called functions

### When Working on Frontend
1. Test with local fork for realistic conditions
2. Handle all transaction states (pending, success, error)
3. Show clear feedback for blockchain interactions
4. Cache contract reads when appropriate
5. Use proper error boundaries for Web3 components

### When Integrating New Features
1. Start with the simplest implementation
2. Write comprehensive tests first
3. Document architectural decisions
4. Consider backwards compatibility
5. Plan for progressive enhancement