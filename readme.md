# DebtHook Protocol

A revolutionary DeFi lending protocol that combines Uniswap V4 hooks for efficient liquidations with EigenLayer AVS for decentralized order matching creating the most capital-efficient lending market.

## Overview

DebtHook is a lending protocol that leverages three key innovations:

1. **Uniswap V4 Hooks**: Atomic liquidations within swap transactions
2. **EigenLayer AVS**: Decentralized debt order matching with Coincidence of Wants (CoW)
3. **Circle Paymaster Integration**: Users pay transaction fees with USDC instead of ETH 

## Core Mechanics

### How It Works

1. **Order Creation**:
   - Lenders and borrowers submit orders to the EigenLayer AVS
   - Orders specify principal amounts, interest rate ranges, and maturity dates
   - No on-chain transaction required - orders are signed off-chain

2. **Order Matching**:
   - EigenLayer operators run the CoW matching algorithm
   - Finds optimal interest rates that benefit both parties
   - Batches multiple orders for gas efficiency
   - Example: Lender wants 5% minimum, Borrower accepts 6% maximum → Match at 5.5%

3. **Loan Execution**:
   - Matched orders execute in batches on-chain
   - USDC transfers from lenders to borrowers
   - Borrowers deposit ETH collateral following barrier option model from theory.md
   - All loans tracked in the DebtHook contract

4. **Liquidations**:
   - Implements barrier option model: liquidation triggers when C_t = D_t (collateral equals debt)
   - This creates a "Down-and-Out Call" for borrowers and "Protected Put" for lenders
   - Executes atomically within ETH/USDC swaps via V4 hooks
   - No separate liquidation bots or transactions needed
   - 5% liquidation penalty to treasury, remaining collateral returns to borrower

### Key Innovations

#### 1. EigenLayer Verified CoW for Interest Rates
Unlike traditional lending protocols where rates are set by utilization curves, DebtHook uses Coincidence of Wants matching:

```
Traditional: Fixed rates based on pool utilization
DebtHook: Dynamic rates based on order matching

Example:
- Alice: Wants to lend 10,000 USDC at 5%+ APR
- Bob: Wants to borrow 10,000 USDC at 6%- APR
- Result: Matched at 5.5% APR (optimal for both)
```
#### 2. All-or-Nothing Fair Liquidation
Unlike traditional lending protocols where liquidation depends on keepers, we leverage hooks to run all-or-nothing liquidations that disperse payouts fairly:

```
Traditional: MEV-prone keeper liquidations with race conditions
DebtHook: Atomic liquidations within swap transactions

Example:
- Loan becomes liquidatable (C_t = D_t)
- Next ETH/USDC swap automatically triggers liquidation
- Lender receives full debt repayment
- Treasury gets 5% penalty
- Borrower gets remaining collateral
```

## 🏗️ Architecture

### Smart Contracts

1. **DebtHook.sol**: Core lending logic with V4 hook integration
   - Manages loans and collateral
   - Implements beforeSwap/afterSwap for automatic liquidations
   - Handles batch loan creation from matched orders
   - Uses transient storage (TSTORE/TLOAD) for gas-efficient liquidation data
   - Hook permissions: beforeSwap (bit 7), afterSwap (bit 6), beforeSwapReturnDelta

2. **DebtOrderBook.sol**: Order management with EIP-712 signatures
   - Validates signed orders
   - Integrates with EigenLayer ServiceManager
   - Maintains backward compatibility for direct orders
   - Implements EIP-712 domain separator for secure signatures

3. **DebtOrderServiceManager.sol**: EigenLayer AVS for matching
   - Receives orders from DebtOrderBook
   - Coordinates operator responses
   - Validates operator minimum stake weight
   - Triggers batch execution in DebtHook

### Technical Implementation Details

#### V4 Hook Mechanics
- **Hook Address Mining**: Must deploy to address with permission bits 6 & 7 set
- **beforeSwap**: Scans for liquidatable positions (health factor < 1.5)
- **afterSwap**: Executes liquidation and distributes proceeds
- **Transient Storage**: Uses assembly TSTORE/TLOAD for passing data between callbacks
- **Gas Optimization**: Liquidations piggyback on existing swaps (no separate transactions)

#### Liquidation Model
Implements a **Barrier Option Model** based on financial theory:
- Liquidation triggers when collateral value equals debt value (C_t = D_t)
- Surplus collateral after debt repayment returns to borrower
- 5% liquidation penalty goes to treasury
- Creates a "Down-and-Out Call" for borrowers and "Protected Put" for lenders

#### Interest Calculation
Uses **continuous compounding** with PRB Math library for precision:
```
A_t = P * e^(r*t)
where:
- P = principal amount
- r = annual interest rate
- t = time in years
- e = Euler's number
```
This ensures fair interest accrual regardless of repayment timing.

### EigenLayer Integration Architecture

**No Cross-Chain Communication Required!** The architecture is elegantly simple:

1. **Orders are signed off-chain** using EIP-712 (signatures work on any chain)
2. **EigenLayer AVS on Ethereum Sepolia** acts as a decentralized verification layer
3. **All DeFi execution happens on Unichain Sepolia** (lending, liquidations, etc.)

```
User Flow:
1. Sign order (off-chain) → 
2. Submit to operators (API) → 
3. Operators match & create proof (Ethereum) → 
4. Submit proof to DebtOrderBook (Unichain) → 
5. Execute loans (Unichain)
```

This design avoids cross-chain complexity while leveraging EigenLayer's security guarantees.

### Off-Chain Components

1. **Operator Node** (TypeScript):
   - Monitors new loan orders
   - Runs CoW matching algorithm
   - Submits matched batches to Unichain (not cross-chain!)
   - Optimizes for best interest rates

2. **Frontend** (Next.js):
   - Order creation interface
   - Portfolio management dashboard
   - Real-time order book visualization
   - Smart wallet integration for gas abstraction

## 🔄 User Flows

### For Lenders
1. Connect wallet (supports both EOA and smart wallets)
2. Create loan offer specifying amount and minimum rate
3. Sign off-chain with EIP-712
4. Order submitted to EigenLayer AVS
5. Receive notification when matched
6. USDC automatically transferred on match

### For Borrowers
1. Browse available liquidity or create custom order
2. Specify loan amount and maximum acceptable rate
3. Order matched by operators
4. Deposit ETH collateral after matching
5. Receive USDC instantly
6. Monitor position health in dashboard

## 🛡️ Security Features

- **Atomic Liquidations**: No MEV extraction possible
- **EigenLayer Security**: Operators stake assets and can be slashed
- **Chainlink Oracles**: Reliable ETH/USD price feeds
- **Dynamic Collateral Model**: Barrier option liquidation when C_t = D_t
- **Signature Validation**: EIP-712 prevents order tampering

## 🚦 Deployment Status

### Current State: Ready for Testnet ✅
- V4 hook implementation complete with automated liquidations
- EigenLayer AVS integration for decentralized order matching
- All core functionality tests passing
- Awaiting hook address mining and deployment

### Mainnet Contracts (Coming Soon)
- DebtHook: `0x...` (requires mined address with bits 6 & 7)
- DebtOrderBook: `0x...`
- DebtOrderServiceManager: `0x...`

### Testnet (Unichain Sepolia)
- Chain ID: 1301
- RPC: https://sepolia.unichain.org
- Explorer: https://sepolia.uniscan.xyz
- Chainlink ETH/USD: 0xd9c93081210dFc33326B2af4C2c11848095E6a9a

### Deployment Checklist
- [ ] Mine hook address with HookMiner (bits 6 & 7 set)
- [ ] Deploy ChainlinkPriceFeed wrapper
- [ ] Deploy DebtHook with CREATE2 to mined address
- [ ] Deploy DebtOrderBook and ServiceManager
- [ ] Initialize ETH/USDC pool if needed
- [ ] Register hook with PoolManager
- [ ] Update frontend with contract addresses

## 🛠️ Quick Start

### Prerequisites
- Node.js v18+
- Foundry
- Git with submodule support

### Installation
```bash
# Clone with submodules
git clone --recurse-submodules https://github.com/yourusername/debt-hook
cd debt-hook

# Install dependencies
cd blockchain && forge install
cd ../dapp && pnpm install
cd ../unicow/operator && npm install
```

### Run Operator Node
```bash
cd unicow/operator
cp .env.example .env
# Edit .env with your operator key
npm run start
```

### Deploy Contracts
```bash
cd blockchain

# First, mine the hook address with correct permissions
forge script script/MineHookAddress.s.sol

# Then deploy all contracts
forge script script/DeployHookOptimized.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

## 📋 Deployment Status

> ✅ **Update (Jun 26, 2025)**: Successfully deployed DebtHook with operator authorization! EigenLayer AVS is running on Ethereum Sepolia. The system is ready for end-to-end testing.

| Component | Unichain Sepolia | Ethereum Sepolia | Status |
|-----------|------------------|------------------|---------|
| **Smart Contracts** |
| PoolManager | `0x1d933AB5bdE2b087a28e24A8E5d4DF77021CFEcC` | N/A | ✅ Deployed |
| DebtHook | **`0x49e39eFDE0C93F6601d84cb5C6D24c1B23eB00C8`** ⛏️ | N/A | ✅ Deployed with Auth |
| DebtOrderBook | `0xce060483D67b054cACE5c90001992085b46b4f66` | N/A | ✅ Deployed |
| ChainlinkPriceFeed | `0x3333Bc77EdF180D81ff911d439F02Db9e34e8603` | N/A | ✅ Deployed |
| USDC Mock | `0x73CFC55f831b5DD6E5Ee4CEF02E8c05be3F069F6` | N/A | ✅ Deployed |
| **EigenLayer** |
| ServiceManager | N/A | `0x3333Bc77EdF180D81ff911d439F02Db9e34e8603` | ✅ Deployed |
| StakeRegistry | N/A | `0x3Df55660F015689174cd42F2FF7D2e36564404b5` | ✅ Deployed |
| **Infrastructure** |
| Frontend URL | [v0-humane-banque.vercel.app](https://v0-humane-banque.vercel.app) | | ✅ Ready |
| Supabase | [project-id] | | ✅ Configured |
| EigenLayer Operator | | | ✅ Running |
| Keeper Bot | | | 🟡 Pending |

> ⛏️ **Note**: The DebtHook address was mined to encode V4 hook permissions in the address itself. The address `0x49e39eFDE0C93F6601d84cb5C6D24c1B23eB00C8` has bits 6, 7, and 3 set, enabling `beforeSwap`, `afterSwap`, and `beforeSwapReturnsDelta` callbacks.

### Ready for Testing! 🚀

The protocol is now fully deployed with operator authorization:

1. **✅ DebtHook**: Deployed with mined address and operator authorized
2. **✅ EigenLayer AVS**: ServiceManager running on Ethereum Sepolia  
3. **✅ Operator**: Running and monitoring for orders
4. **🧪 Next**: Submit test orders to verify the complete flow

To test the system:
```bash
# 1. Submit test orders to ServiceManager (Ethereum Sepolia)
# 2. Operator will match and submit to DebtHook (Unichain Sepolia)
# 3. Monitor logs for batch loan creation
```

### Pre-deployment Checklist
- [ ] Run all smart contract tests
- [ ] Mine hook address with correct permissions
- [ ] Verify contract compilation
- [ ] Test frontend build
- [ ] Configure environment variables
- [ ] Set up monitoring

### Post-deployment Tasks
- [ ] Verify all contracts on explorer
- [ ] Test end-to-end flows
- [ ] Configure keeper bot
- [ ] Enable Supabase RLS
- [ ] Set up alerts

## 🎨 Frontend Features

- **Market View**: Real-time order book with depth chart
- **Portfolio Dashboard**: Active positions for lenders and borrowers
- **Order Builder**: Intuitive interface for creating orders
- **Gas Abstraction**: Pay gas in USDC via Circle Paymaster
- **Mobile Responsive**: Full functionality on all devices

## 💳 USDC Gas Payment Integration

DebtHook integrates Circle's USDC Paymaster for seamless gas payments:

### How It Works
1. **Permit Signing**: Users sign an EIP-2612 permit allowing the paymaster to spend USDC
2. **Gas Estimation**: Frontend calculates USDC cost based on current gas prices
3. **Atomic Payment**: Gas fees deducted from USDC balance during transaction
4. **No ETH Required**: Perfect for users who only hold stablecoins

### Implementation Details
- **CirclePaymaster.sol**: EIP-4337 compliant paymaster contract
- **Dynamic Pricing**: Configurable exchange rate (initially 1 USDC = 3000 gwei)
- **Safety Buffer**: 10% markup on gas estimates to handle price fluctuations
- **Frontend Toggle**: Users can choose between ETH or USDC for gas

### Usage Example
```typescript
// Enable USDC gas payment in frontend
const { preparePaymaster } = usePaymaster()
const paymasterData = await preparePaymaster(estimatedGasLimit)

// Transaction automatically uses USDC for gas
await debtOrderBook.createLoanWithOrder(order, signature, {
  paymasterAndData: paymasterData
})
```

## 📊 Protocol Advantages

1. **Better Rates**: CoW matching ensures optimal rates for all parties
2. **Gas Efficiency**: Batch execution reduces costs by 70%+
3. **No Liquidation Bots**: Integrated liquidations save gas and prevent MEV
4. **Decentralized**: No central authority controls the order book
5. **Flexible**: Partial order fills and multiple maturity options

## 🤝 Integration Guide

### For Developers
```typescript
// Submit a lender order
const order = {
  principalAmount: parseUnits("10000", 6), // USDC
  minRate: 500, // 5% APR
  maxRate: 1000, // 10% APR
  maturityTimestamp: Math.floor(Date.now() / 1000) + 30 * 24 * 60 * 60,
  expiry: Math.floor(Date.now() / 1000) + 24 * 60 * 60
};

await debtOrderBook.submitOrderToAVS(order, signature);
```

### For Protocols
DebtHook can be integrated as a lending layer for any protocol needing capital-efficient loans with guaranteed liquidations.

## 🔮 Future Roadmap

### Phase 1: Optimize Current Architecture (Post-MVP Q3 2025)
1. **Enhanced Batch Liquidation System** (Planned)
   - Current implementation handles single liquidations per swap
   - Future: Accumulate multiple liquidations in single transaction
   - Gas savings: ~70% vs individual liquidations
   - Distribute proceeds fairly using delta accounting

2. **Advanced V4 Hook Features**
   - Fee reduction hook for protocol users
   - Loyalty points system for liquidity providers
### Phase 2: USDC Paymaster (Implemented ✅)
- **CirclePaymaster.sol**: Full EIP-4337 paymaster implementation
- **EIP-2612 Permits**: Gasless USDC approvals for fee payment
- **Frontend Integration**: Toggle for USDC gas payments in UI
- **Smart Account Support**: Works with both EOAs and smart wallets
- Users can pay gas in USDC with ~10% buffer for price fluctuations

### Phase 3: Enhanced Features (Q4 2025)
- Multi-collateral support (wBTC)
- Cross-chain lending via LayerZero
- Advanced fixed-rate term structures (current: basic maturity timestamps)

### Phase 4: Advanced DeFi (2026+)
- Institutional API
- Just-In-Time (JIT) liquidity provision
- DAO governance

## 🔧 Technical Considerations

### Gas Optimization Opportunities
- Current: Linear search for liquidatable loans (O(n))
- Planned: Liquidation queue with O(1) access
- Batch processing limits to prevent DOS attacks
- Circuit breakers for maximum liquidations per block

### Security Enhancements
- Slippage protection in liquidation swaps
- Partial liquidation support (max 50% at once)
- Oracle manipulation resistance
- Emergency pause functionality

## 🏆 Hackathon Achievements

Built for the Uniswap V4 Hookathon, DebtHook demonstrates:
- First lending protocol with native V4 hook liquidations
- Pioneer implementation of CoW for debt markets
- Seamless integration of EigenLayer AVS with DeFi
- **USDC Gas Payments**: Full Circle Paymaster integration for gasless transactions

## 📚 Documentation

- [Smart Contract Documentation](./blockchain/README.md)
- [Operator Guide](./unicow/README.md)
- [Frontend Documentation](./dapp/README.md)

## 🤝 Contributing

We welcome contributions! Please see [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

## 📄 License

MIT License - see [LICENSE](./LICENSE) for details.

---

**Built with ❤️ for the Uniswap V4 Hookathon** 🦄
**Thanks Atrium Academy, Uniswap Foundation and accross the globe open source builders**
