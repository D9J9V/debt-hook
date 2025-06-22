# DebtProtocol Deployment Scripts

This directory contains deployment and management scripts for the DebtProtocol system.

## Prerequisites

1. Set up environment variables:
```bash
export PRIVATE_KEY="your_private_key"
export TREASURY="treasury_address" # Optional, defaults to deployer
export RPC_URL="your_rpc_url"
export ETHERSCAN_API_KEY="your_etherscan_api_key" # For verification
```

2. Ensure you have sufficient ETH and test tokens on the deployment network.

## Scripts

### 1. Deploy.s.sol
Deploys the complete DebtProtocol system including:
- PoolManager (if not provided)
- Mock USDC token (for testnet)
- Mock price feed
- DebtProtocol contract
- DebtOrderBook contract
- Initializes the Uniswap v4 pool

**Usage:**
```bash
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast
```

### 2. AddLiquidity.s.sol
Adds liquidity to the initialized pool. This is required before the protocol can perform liquidations.

**Usage:**
```bash
forge script script/AddLiquidity.s.sol --rpc-url $RPC_URL --broadcast
```

### 3. Verify.s.sol
Generates verification commands for all deployed contracts on Etherscan.

**Usage:**
```bash
forge script script/Verify.s.sol
```

Then run the generated commands with your API key:
```bash
forge verify-contract <address> <contract> --constructor-args <args> --etherscan-api-key $ETHERSCAN_API_KEY --rpc-url $RPC_URL
```

## Deployment Process

### Testnet Deployment (Sepolia/Goerli)

1. **Deploy contracts:**
```bash
forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --verify
```

2. **Add initial liquidity:**
```bash
forge script script/AddLiquidity.s.sol --rpc-url $RPC_URL --broadcast
```

3. **Verify contracts (if not auto-verified):**
```bash
forge script script/Verify.s.sol
# Then run the generated verification commands
```

### Mainnet Deployment

1. **Test deployment on fork:**
```bash
forge script script/Deploy.s.sol --fork-url $RPC_URL
```

2. **Deploy with hardware wallet:**
```bash
forge script script/Deploy.s.sol --rpc-url $RPC_URL --ledger --broadcast
```

3. **Verify deployment:**
- Check all contract addresses in `deployments/latest.json`
- Verify contract code on Etherscan
- Test basic operations (create loan, repay, liquidate)

## Post-Deployment

### Configuration
After deployment, you may need to:
1. Transfer ownership of contracts if needed
2. Set up keeper bots for automated liquidations
3. Configure monitoring and alerts
4. Update frontend with deployment addresses

### Testing
Run integration tests on the deployed contracts:
```bash
forge test --fork-url $RPC_URL --fork-block-number <deployment_block>
```

## Deployment Addresses

Deployment addresses are saved to `deployments/latest.json` after each deployment:
```json
{
  "chainId": 11155111,
  "poolManager": "0x...",
  "usdc": "0x...",
  "priceFeed": "0x...",
  "debtProtocol": "0x...",
  "debtOrderBook": "0x...",
  "treasury": "0x..."
}
```

## Troubleshooting

### Common Issues

1. **Insufficient gas**: Increase gas limit in foundry.toml
2. **Pool initialization fails**: Ensure currencies are sorted correctly (address(0) < USDC address)
3. **Verification fails**: Check constructor arguments match exactly

### Emergency Procedures

In case of issues:
1. Contracts are not upgradeable - redeploy if critical bug found
2. Treasury can be used to recover stuck funds (implement recovery function)
3. Monitor liquidation events for anomalies

## Gas Costs (Estimates)

- Full deployment: ~5M gas
- Pool initialization: ~200k gas
- Adding liquidity: ~300k gas
- Total ETH needed: ~0.1 ETH on mainnet (at 30 gwei)

## Security Checklist

Before mainnet deployment:
- [ ] Contracts audited
- [ ] Deployment script tested on testnet
- [ ] Access controls verified
- [ ] Price feed oracle validated
- [ ] Liquidation mechanics tested
- [ ] Gas optimizations implemented
- [ ] Emergency pause mechanism (if applicable)