# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DebtHook is a DeFi lending protocol that leverages Uniswap v4 hooks for efficient liquidations. The protocol enables collateralized lending with ETH as collateral and USDC as the lending currency, featuring:

- **Smart Contracts**: Solidity contracts using Foundry framework with Uniswap v4 integration
- **Frontend**: Next.js app with TypeScript, shadcn/ui components, and Web3 integration
- **Backend**: Supabase for off-chain order management and indexing
- **Key Innovation**: Liquidations execute directly through Uniswap v4 swaps via hook mechanics

## Implementation Status (June 26, 2025)

### Phase A: Uniswap V4 Hook ✅ DEPLOYED
**Status**: Successfully deployed to Unichain Sepolia
- DebtHook deployed at: `0x49e39eFDE0C93F6601d84cb5C6D24c1B23eB00C8`
- True V4 hook with beforeSwap/afterSwap callbacks
- Automatic liquidations during ETH/USDC swaps
- MEV-protected atomic liquidation execution
- Mined address with permission bits 6, 7, and 3

### Phase B: USDC Paymaster ✅ IMPLEMENTED
**Status**: Fully implemented and ready for deployment
- EIP-4337 compliant CirclePaymaster contract
- Sponsors gas fees and accepts USDC as payment
- Dynamic pricing mechanism (1 USDC = 3000 gwei initial rate)
- EIP-2612 permit support for gasless approvals
- Seamless UX for users holding only USDC

### Phase C: EigenLayer Integration ✅ DEPLOYED
**Status**: Successfully deployed and operational
- ServiceManager deployed at: `0x3333Bc77EdF180D81ff911d439F02Db9e34e8603` (Ethereum Sepolia)
- Operator running at: `0x2f131a86C5CB54685f0E940B920c54E152a44B02`
- Authorized to create batch loans on DebtHook
- **UniCow Integration**: CoW matching for debt orders (NOT liquidations)
- Optimal interest rate discovery through batch matching
- See `unicow/README.md` for rationale and `unicow/CLAUDE.md` for implementation

#### Batch Matching Features
- **Dual Execution Modes**: Direct (instant) or Batch (optimized rates)
- **Flexible Parameters**: Min/max principal amounts and interest rate ranges
- **5-minute Batch Windows**: Configurable collection periods
- **Partial Fill Support**: Orders can be partially matched
- **Gas Efficiency**: Batch execution reduces per-order costs

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
├── unicow/             # EigenLayer AVS for CoW market making (submodule)
│   ├── hook/           # Uniswap v4 hook for CoW matching
│   ├── avs/            # EigenLayer service manager
│   └── operator/       # TypeScript operator implementation
└── supabase/           # Database schema and edge functions
    ├── migrations/     # SQL migrations for tables and views
    └── functions/      # Edge functions for batch processing
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
2. **unicow**: EigenLayer AVS for Coincidence of Wants market making

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
git submodule update --remote unicow

# Commit submodule changes
git add dapp unicow
git commit -m "Update submodules"
```

## V4 Hook Implementation Details

### Hook Permissions and Address Mining
DebtHook must be deployed to an address with specific permission bits set:
- **Bit 7 (BEFORE_SWAP_FLAG)**: Enables `beforeSwap` callback
- **Bit 6 (AFTER_SWAP_FLAG)**: Enables `afterSwap` callback
- **Bit 3 (BEFORE_SWAP_RETURNS_DELTA_FLAG)**: Enables swap amount modification

The deployment process requires:
1. Use `HookMiner` to find a salt that produces an address with bits 6, 7 & 3 set
2. Deploy using CREATE2 with the mined salt
3. Verify the deployed address matches expected permissions

**Current Deployment**: `0x49e39eFDE0C93F6601d84cb5C6D24c1B23eB00C8` has the correct permission bits

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

### Current Deployment (June 26, 2025)

#### Unichain Sepolia
- **DebtHook**: `0x49e39eFDE0C93F6601d84cb5C6D24c1B23eB00C8` (with operator authorization)
- **DebtOrderBook**: `0xce060483D67b054cACE5c90001992085b46b4f66`
- **PoolManager**: `0x1d933AB5bdE2b087a28e24A8E5d4DF77021CFEcC`
- **USDC Mock**: `0x73CFC55f831b5DD6E5Ee4CEF02E8c05be3F069F6`
- **ChainlinkPriceFeed**: `0x3333Bc77EdF180D81ff911d439F02Db9e34e8603`

#### Ethereum Sepolia
- **ServiceManager**: `0x3333Bc77EdF180D81ff911d439F02Db9e34e8603`
- **StakeRegistry**: `0x3Df55660F015689174cd42F2FF7D2e36564404b5`

#### Operator
- **Address**: `0x2f131a86C5CB54685f0E940B920c54E152a44B02` (authorized on DebtHook)

## Deployment Process

### Smart Contract Deployment
```bash
# 1. Deploy contracts
cd blockchain
forge script script/Deploy.s.sol \
  --rpc-url $UNICHAIN_SEPOLIA_RPC \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify

# 2. Set ServiceManager for AVS
cast send $DEBT_ORDER_BOOK_ADDRESS \
  "setServiceManager(address)" \
  $SERVICE_MANAGER_ADDRESS \
  --rpc-url $UNICHAIN_SEPOLIA_RPC \
  --private-key $PRIVATE_KEY
```

### EigenLayer AVS Setup
```bash
# 1. Deploy ServiceManager
cd unicow/contracts
forge script script/DeployServiceManager.s.sol \
  --rpc-url $ETHEREUM_SEPOLIA_RPC \
  --private-key $PRIVATE_KEY \
  --broadcast

# 2. Configure and start operator
cd ../operator
npm install
npm run register-operator
npm run start
```

### Frontend Deployment
```bash
# 1. Update environment variables
cd dapp
cp .env.example .env.local
# Edit .env.local with deployed addresses

# 2. Build and deploy
pnpm build
vercel --prod
```

### Supabase Configuration
1. Apply database migrations in order
2. Deploy edge functions for batch processing
3. Configure webhooks for batch events
4. Enable Row Level Security policies

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

## Troubleshooting

### Common Issues
1. **ServiceManager not set**: Use `setServiceManager` function on DebtOrderBook
2. **Hook address permissions**: Ensure mined address has bits 6 & 7 set
3. **Batch not executing**: Check operator status and minimum order threshold
4. **Frontend not showing batch option**: Verify ServiceManager configuration

### Monitoring
- Contract events: Use cast logs or Tenderly
- Operator status: Check operator logs
- Batch execution: Monitor Supabase batch tables
- Gas usage: Track via Dune Analytics