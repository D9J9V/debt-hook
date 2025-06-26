# EigenLayer AVS Deployment Guide

## ✅ Deployment Complete!

### Deployed Addresses

#### Ethereum Sepolia (EigenLayer AVS)
- **ServiceManager Proxy**: `0x3333Bc77EdF180D81ff911d439F02Db9e34e8603`
- **ServiceManager Implementation**: `0xF12b7dd6E49FBF196A6398BEF6C7aD29C7818a7B`
- **StakeRegistry Proxy**: `0x3Df55660F015689174cd42F2FF7D2e36564404b5`
- **StakeRegistry Implementation**: `0x84FACEcBea30a44305c96d0727C814cBbeE9F9A3`

#### Unichain Sepolia (DeFi Contracts)
- **DebtHook**: `0x0C075a62FD69EA6Db1F65566911C4f1D221e40c8`
- **DebtOrderBook**: `0xDB8cFf278adCCF9E9b5da745B44E754fC4EE3C76`

### Integration Status
- ✅ ServiceManager deployed to Ethereum Sepolia
- ✅ DebtOrderBook connected to ServiceManager
- ✅ Operator environment configured
- 🔄 Ready for operator registration and testing

## Next Steps

### 1. Register and Start Operator
```bash
cd unicow/operator
npm run register-operator
npm run start
```

### 2. Authorize Operator in DebtHook
After starting the operator, get its address from the console and authorize it:
```solidity
// TODO: Add this function to DebtHook
debtHook.authorizeOperator(operatorAddress);
```

### 3. Test the Integration
Submit test orders through the frontend or scripts to see the matching in action.

## Architecture Recap

The system works without cross-chain complexity:
1. Users sign orders off-chain (EIP-712)
2. EigenLayer AVS on Ethereum provides operator security
3. All DeFi execution happens on Unichain
4. Operators simply submit matched batches as regular transactions

## Operator Monitoring

When the operator is running, you'll see:
- New order detection
- Batch formation every 10 blocks
- Matching results with optimal rates
- Transaction submissions to Unichain