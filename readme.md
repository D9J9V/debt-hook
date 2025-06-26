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
**Goal**: Enable users to interact with the protocol using only USDC

Users will be able to pay transaction fees in USDC instead of ETH, removing friction for those who only hold stablecoins. This will be implemented using EIP-4337 account abstraction.

**Planned Features**:
- Pay gas fees in USDC
- Seamless UX for non-ETH holders
- Integration with existing wallet infrastructure
- Automatic fee conversion and settlement

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

## Security Considerations

- All contracts are designed with security-first principles
- Chainlink oracles prevent price manipulation
- EIP-712 signatures prevent order tampering
- Atomic liquidations eliminate MEV opportunities
- Comprehensive test coverage ensures reliability

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for development guidelines.

## License

MIT License - see [LICENSE](./LICENSE) for details.

---

Built for the Uniswap V4 Hookathon 🦄