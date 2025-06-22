# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the smart contract component of a DeFi lending protocol that leverages Uniswap v4 hooks for liquidation mechanics. The protocol enables collateralized lending with ETH as collateral and USDC as the lending currency.

## Common Commands

```bash
# Build all contracts
forge build

# Run all tests
forge test

# Run specific test
forge test --match-test <testName>

# Run tests with gas reporting
forge test --gas-report

# Format Solidity code
forge fmt

# Generate gas snapshot
forge snapshot

# Deploy contracts (example)
forge script script/Deploy.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY>
```

## Architecture Overview

### Core Contracts

1. **DebtHook.sol**: Main protocol implementation
   - Inherits from Uniswap v4's `BaseHook`
   - Implements loan lifecycle: creation, repayment, liquidation
   - Key functions:
     - `createLoan()`: Creates collateralized debt positions
     - `repayLoan()`: Handles loan repayment
     - `liquidateLoan()`: Triggers liquidation through Uniswap swaps 

2. **DebtOrderBook.sol**: Off-chain order management
   - Implements EIP-712 for gasless signed orders
   - Key components:
     - `LoanOrder` struct: Defines order parameters
     - `createLoanWithOrder()`: Executes signed orders on-chain
     - Domain separator and type hashes for signature validation

3. **IDebtHook.sol**: Interface definitions
   - Contains all structs, events, and function signatures
   - Critical structs: `Loan`, `LoanOrder`, `LiquidationData`

### Key Design Patterns

1. **Liquidation**: The protocol uses a Uniswap v4 pool to execute liquidations efficiently. 

2. **Storage Pattern**: Uses mappings for loan storage with incremental IDs:
   - `loans`: Main loan storage (loanId => Loan)
   - `liquidationData`: Temporary storage during liquidation
   - `borrowerLoans`/`lenderLoans`: User loan tracking

3. **Security Considerations**:
   - Reentrancy protection on critical functions
   - Signature replay prevention via nonces
   - Access control for hook registration

## Testing Approach

The main test file `test/DebtProtocol.t.sol` covers:
- Complete loan lifecycle testing
- Edge cases for liquidation scenarios
- Order signature validation
- Integration with Uniswap v4 pools

When adding new functionality, follow the existing test patterns using Foundry's testing framework.

## Development Notes

1. **Hook Registration**: DebtHook must be properly registered with the PoolManager before use

2. **Price Oracles**: Currently uses mock prices. Production will integrate Chainlink oracles

3. **Liquidation Threshold**: Set at 150% collateralization ratio (health factor < 1.5 triggers liquidation)

4. **Gas Optimization**: The contract uses custom errors and efficient storage patterns. Continue this approach for new features

5. **Foundry Remappings**: Dependencies are remapped in `foundry.toml`:
   - `@uniswap/v4-core/` → `lib/v4-core/`
   - `@uniswap/v4-periphery/` → `lib/v4-periphery/`
