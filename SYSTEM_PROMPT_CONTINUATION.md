# System Prompt: DebtHook Protocol Deployment Continuation

## Current Status (As of Jun 26, 2025)

### ✅ Deployed Contracts

#### Unichain Sepolia (Chain ID: 1301)
- **PoolManager**: `0x5b73C5498c1E3b4dbA84de0F1833c4a029d90519`
- **DebtHook**: `0x0C075a62FD69EA6Db1F65566911C4f1D221e40c8` (Mined address with hook permissions)
- **DebtOrderBook**: `0xDB8cFf278adCCF9E9b5da745B44E754fC4EE3C76` 
- **ChainlinkPriceFeed**: `0x34A1D3fff3958843C43aD80F30b94c510645C316`
- **USDC Mock**: `0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496`

#### Ethereum Sepolia (Chain ID: 11155111)
- **ServiceManager**: `0x3333Bc77EdF180D81ff911d439F02Db9e34e8603`
- **StakeRegistry**: `0x3Df55660F015689174cd42F2FF7D2e36564404b5`

### ✅ Completed Tasks
1. Deployed all core smart contracts to Unichain Sepolia
2. Successfully mined hook address with correct permission bits
3. Deployed EigenLayer AVS (ServiceManager) to Ethereum Sepolia
4. Connected ServiceManager to DebtOrderBook via `setServiceManager()`
5. Configured and started operator service (monitoring for orders)
6. Updated all documentation and deployment guides

### 🔄 Current Architecture
- **No Cross-Chain Bridges**: Orders are signed off-chain (EIP-712)
- **Operator Flow**: Monitor Ethereum → Match orders → Submit to Unichain
- **Operator Address**: `0x2f131a86C5CB54685f0E940B920c54E152a44B02`
- **Frontend URL**: https://v0-humane-banque.vercel.app

### ⚠️ Pending Tasks

1. **Update DebtHook Contract** (CRITICAL)
   - Current `createBatchLoans` has TODO comment for operator validation
   - Need to add `authorizedOperators` mapping
   - Deploy updated contract and authorize operator

2. **Test End-to-End Flow**
   - Submit test orders via frontend or scripts
   - Verify operator matching
   - Confirm loan execution

3. **Frontend Updates**
   - Add "Submit to AVS" option
   - Show batch matching status
   - Update contract addresses if changed

4. **Deploy Keeper Bot**
   - For liquidation monitoring
   - Health factor tracking

### 📁 Key Files
- `blockchain/src/DebtHook.sol` - Main hook contract (needs operator auth)
- `blockchain/src/DebtOrderBook.sol` - Order management (already integrated)
- `unicow/avs/src/DebtOrderServiceManager.sol` - EigenLayer AVS
- `unicow/operator/simple-operator.ts` - Running operator service
- `dapp/` - Frontend application

### 🔑 Environment Variables
```bash
# Already configured in unicow/operator/.env
ETHEREUM_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/ivTm1S1g-D8mFcNlmwGluBjM7-O2X1Q4
SERVICE_MANAGER_ADDRESS=0x3333Bc77EdF180D81ff911d439F02Db9e34e8603
DEBT_HOOK_ADDRESS=0x0C075a62FD69EA6Db1F65566911C4f1D221e40c8
DEBT_ORDER_BOOK_ADDRESS=0xDB8cFf278adCCF9E9b5da745B44E754fC4EE3C76
PRIVATE_KEY=0xc50d3eaed4263e8ad7a32a36708b4d359b391bcd2624577ab0267dd6055b7b92
```

### 🎯 Next Steps Priority
1. Add operator authorization to DebtHook
2. Deploy updated DebtHook contract
3. Test order submission and matching
4. Update frontend for AVS integration
5. Set up monitoring and alerts

### 💡 Important Notes
- The multi-chain setup is intentional and doesn't require bridges
- EigenLayer provides operator security, Unichain handles execution
- All contracts are on testnets (Sepolia variants)
- Operator is currently running and monitoring for orders

Continue from: Adding operator authorization to DebtHook contract...