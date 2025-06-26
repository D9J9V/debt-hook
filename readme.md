# DebtHook Protocol

A next-generation DeFi lending protocol built on Uniswap V4, enabling efficient collateralized lending with automated liquidations through hook mechanics.

## Overview

DebtHook revolutionizes DeFi lending by integrating directly with Uniswap V4's hook system. This allows liquidations to occur automatically during regular swap transactions, eliminating the need for separate liquidation bots and providing MEV protection.

### Key Features

- **🪝 True V4 Hook**: Liquidations execute within swap transactions via beforeSwap/afterSwap callbacks
- **⚡ Gas Efficient**: No separate liquidation transactions needed
- **🛡️ MEV Protected**: Atomic liquidations prevent frontrunning
- **✍️ Gasless Orders**: Lenders create loan offers off-chain with EIP-712 signatures
- **📊 Fair Liquidations**: Surplus collateral returned to borrowers
- **🔗 Chainlink Integration**: Real-time ETH/USD price feeds

## Implementation Roadmap

### Phase A: Uniswap V4 Hook ✅ (Current Focus)
**Status**: Core implementation complete, preparing for Unichain Sepolia deployment

The protocol implements a true V4 hook that monitors the ETH/USDC pool for liquidation opportunities. When a swap occurs, the hook checks all active loans and automatically liquidates underwater positions within the same transaction.

**Key Components**:
- `DebtHook.sol`: Main protocol with V4 hook callbacks
- `DebtOrderBook.sol`: Manages EIP-712 signed loan offers
- `ChainlinkPriceFeed.sol`: Oracle integration for price data

**Deployment**:
```bash
# Quick deployment to Unichain Sepolia
export PRIVATE_KEY="your-private-key"
export RPC_URL="https://unichain-sepolia-rpc.publicnode.com"
forge script blockchain/script/DeployHookOptimized.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```

**Next Steps**:
- [x] Mine hook address with correct permission bits
- [ ] Deploy to Unichain Sepolia testnet
- [ ] Verify contracts and update frontend
- [ ] Conduct thorough testing on testnet

### Phase B: USDC Paymaster 🚧 (Next Priority)
**Goal**: Enable USDC lenders to participate without holding ETH

Following [Circle's USDC Paymaster implementation guide](https://developers.circle.com/stablecoins/quickstart-circle-paymaster), we're implementing gas payment in USDC to remove a key friction point for lenders.

**Design Rationale**:
USDC lenders often hold stablecoins exclusively and shouldn't need to acquire ETH just to create loan offers. By integrating Circle's Paymaster (v0.8), lenders can:
- Create loan offers paying gas in USDC
- Claim repayments without ETH
- Manage positions using only stablecoins
- Enjoy a seamless, stablecoin-native experience

**Technical Implementation**:
- EIP-4337 account abstraction with smart wallets
- Circle Paymaster for USDC gas payment
- EIP-2612 permits for gasless approvals
- Integration with Privy's smart wallet infrastructure

**Planned Features**:
- Pay gas fees in USDC for all lender operations
- Automatic USDC permit generation
- Bundler integration for UserOperation submission
- Seamless fallback to ETH for borrowers (who need ETH for collateral anyway)

### Phase C: Eigenlayer AVS 🔮 (Future Enhancement)
**Goal**: Create a verifiable and decentralized orderbook

The orderbook will become fully decentralized with cryptographic proofs of integrity. Eigenlayer operators will validate orders and can be slashed for malicious behavior.

**Planned Features**:
- Cryptographically verifiable order matching
- Slashing mechanisms for bad actors
- Decentralized order validation
- Enhanced trust and transparency

## Project Structure

```
debt-hook/
├── blockchain/         # Smart contracts (Foundry)
│   ├── src/           # Contract source files
│   ├── test/          # Contract tests
│   └── script/        # Deployment scripts
├── dapp/              # Frontend application (Next.js)
│   ├── app/           # App router pages
│   ├── components/    # React components
│   └── lib/           # Utilities and hooks
└── docs/              # Documentation and theory
```

## Quick Start

### Prerequisites
- [Foundry](https://getfoundry.sh/) for smart contract development
- [Node.js](https://nodejs.org/) v18+ and pnpm for frontend
- [Git](https://git-scm.com/) with submodule support

### Installation

```bash
# Clone with submodules
git clone --recurse-submodules <repo-url>
cd debt-hook

# Install contract dependencies
cd blockchain
forge install

# Install frontend dependencies
cd ../dapp
pnpm install
```

### Development

```bash
# Run contract tests
cd blockchain
forge test

# Start frontend dev server
cd dapp
pnpm dev
```

## Deployment Target

**Network**: Unichain Sepolia
- Chain ID: 1301
- RPC: https://sepolia.unichain.org
- Explorer: https://sepolia.uniscan.xyz

## USDC Paymaster Architecture

### Overview
The USDC Paymaster integration enables lenders to interact with DebtHook using only USDC, eliminating the need to hold ETH for gas fees. This is particularly important for institutional lenders and stablecoin-focused users.

### Technical Flow
1. **Smart Wallet Creation**: Users get a smart wallet (EIP-4337) through Privy
2. **USDC Permit**: Users sign an EIP-2612 permit allowing the Paymaster to spend USDC
3. **UserOperation**: Transactions are bundled as UserOperations with paymaster data
4. **Gas Payment**: Circle's Paymaster deducts gas costs from user's USDC balance
5. **Transaction Execution**: The bundler submits the transaction on-chain

### Integration Points
- **Frontend**: Privy SDK handles smart wallet creation and UserOp building
- **Paymaster**: Circle's USDC Paymaster (v0.8) on supported networks
- **Contracts**: `USDCPaymasterIntegration.sol` provides helper functions
- **Bundler**: Third-party bundler service (e.g., Pimlico) for UserOp submission

### Configuration Steps

1. **Privy Dashboard Setup**:
   - Navigate to your app settings in [Privy Dashboard](https://dashboard.privy.io)
   - Enable "Smart Wallets" under the Wallets section
   - Add Circle's USDC Paymaster URL: `https://paymaster.circle.com/v1/rpc`
   - Configure supported networks (ensure USDC is available)

2. **Frontend Integration**:
   - Users see "Pay gas with USDC" toggle in the UI
   - When enabled, transactions use smart wallets with paymaster
   - Automatic fallback to regular wallets if paymaster fails

3. **Smart Contract Compatibility**:
   - All contract functions work with both EOA and smart wallets
   - No changes needed to existing contract code
   - Paymaster handles gas abstraction transparently

### Benefits for Lenders
- **No ETH Required**: Create and manage loan offers with only USDC
- **Simplified UX**: One-token experience for stablecoin users
- **Lower Barriers**: Easier onboarding for traditional finance users
- **Cost Transparency**: Gas fees shown and paid in USDC

## Security Considerations

- All contracts are designed with security-first principles
- Chainlink oracles prevent price manipulation
- EIP-712 signatures prevent order tampering
- Atomic liquidations eliminate MEV opportunities
- Comprehensive test coverage ensures reliability
- USDC Paymaster uses secure permit signatures

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for development guidelines.

## License

MIT License - see [LICENSE](./LICENSE) for details.

---

Built for the Uniswap V4 Hookathon 🦄