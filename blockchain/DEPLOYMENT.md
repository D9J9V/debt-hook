# DebtHook Deployment Guide

This guide covers the deployment process for the DebtHook protocol on Unichain Sepolia.

## Prerequisites

1. **Environment Setup**
   ```bash
   # Install dependencies
   forge install
   
   # Set environment variables
   export PRIVATE_KEY=<your-private-key>
   export RPC_URL=https://unichain-sepolia-rpc.publicnode.com
   export TREASURY=<treasury-address> # Optional, defaults to deployer
   export ETHERSCAN_API_KEY=<api-key> # For contract verification
   ```

2. **Fund Deployer**
   - Ensure your deployer address has sufficient ETH on Unichain Sepolia
   - Get testnet ETH from the Unichain Sepolia faucet

## Deployment Options

### Option 1: Production Deployment with Hook Mining (Recommended)

This deploys the DebtHook to a properly mined address with the correct permission bits.

```bash
forge script script/DeployHookOptimized.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

**What this does:**
1. Mines an address with permission bits for `beforeSwap`, `afterSwap`, and `beforeSwapReturnsDelta`
2. Deploys all contracts in the correct order
3. Resolves circular dependencies between DebtHook and DebtOrderBook
4. Initializes the ETH/USDC pool
5. Outputs deployment addresses and configuration

### Option 2: Simple Deployment (Testing Only)

For quick testing without proper hook address mining:

```bash
forge script script/DeploySimple.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```

⚠️ **WARNING**: This deployment does not use proper hook address mining and will not work correctly with Uniswap V4's hook validation!

### Option 3: Step-by-Step Manual Deployment

For more control over the deployment process:

```bash
# 1. Test hook mining locally
forge script script/TestHookMining.s.sol

# 2. Deploy with detailed logging
forge script script/DeployHook.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  -vvvv
```

## Hook Permission Requirements

The DebtHook requires the following permission bits:
- `BEFORE_SWAP_FLAG` (0x80): bit 7
- `AFTER_SWAP_FLAG` (0x40): bit 6
- `BEFORE_SWAP_RETURNS_DELTA_FLAG` (0x08): bit 3

Combined: `0xC8` (binary: `11001000`)

These permissions enable:
- Scanning for liquidatable loans before swaps
- Executing liquidations after swaps
- Modifying swap amounts to include liquidation collateral

## Post-Deployment Steps

1. **Verify Contracts**
   ```bash
   # Example verification command
   forge verify-contract <DEBT_HOOK_ADDRESS> DebtHook \
     --chain-id 1301 \
     --verifier blockscout \
     --verifier-url https://sepolia.uniscan.xyz/api \
     --constructor-args $(cast abi-encode "constructor(address,address,address,address,address,address,uint24,int24)" \
       <POOL_MANAGER> <PRICE_FEED> <ORDER_BOOK> <TREASURY> <ETH> <USDC> 3000 60)
   ```

2. **Add Liquidity to Pool**
   ```bash
   # Use the frontend or a script to add liquidity to the ETH/USDC pool
   ```

3. **Configure Frontend**
   Copy the deployment output to your frontend `.env`:
   ```env
   NEXT_PUBLIC_POOL_MANAGER=0x...
   NEXT_PUBLIC_USDC_ADDRESS=0x...
   NEXT_PUBLIC_DEBT_HOOK=0x...
   NEXT_PUBLIC_DEBT_ORDER_BOOK=0x...
   ```

4. **Test Basic Operations**
   - Create a loan order through the frontend
   - Accept a loan order
   - Test repayment
   - Test liquidation (if possible)

## Troubleshooting

### Hook Address Mining Fails
- Increase the `MAX_LOOP` constant in HookMiner if needed
- Ensure CREATE2_DEPLOYER is available on your network
- Check that constructor arguments are correctly encoded

### Deployment Reverts
- Ensure sufficient ETH for deployment
- Check that Chainlink price feed is available at the expected address
- Verify RPC endpoint is correct for Unichain Sepolia

### Contract Verification Fails
- Ensure correct compiler version (0.8.24)
- Match constructor arguments exactly
- Use the correct verification API endpoint

## Network Information

**Unichain Sepolia**
- Chain ID: 1301
- RPC: https://unichain-sepolia-rpc.publicnode.com
- Explorer: https://sepolia.uniscan.xyz
- Chainlink ETH/USD: 0xd9c93081210dFc33326B2af4C2c11848095E6a9a

## Gas Estimates

Approximate gas costs for deployment:
- PoolManager: ~3M gas
- DebtHook: ~4M gas
- DebtOrderBook: ~2M gas
- Total: ~10M gas

## Security Checklist

Before mainnet deployment:
- [ ] Audit smart contracts
- [ ] Test all edge cases on testnet
- [ ] Verify hook permissions are correct
- [ ] Ensure treasury address is a multisig
- [ ] Set up monitoring and alerts
- [ ] Create emergency pause mechanism
- [ ] Document incident response plan