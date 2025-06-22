# CLAUDE.md - Smart Contracts

This file provides guidance to Claude Code (claude.ai/code) when working with the smart contract code in this repository.

## Project Overview

This is the smart contract component of the DebtHook protocol, a DeFi lending platform that leverages Uniswap v4 hooks for efficient liquidations. The protocol enables collateralized lending with ETH as collateral and USDC as the lending currency, featuring innovative liquidation mechanics through AMM integration.

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

1. **Liquidation**: The protocol uses a Uniswap v4 pool to execute liquidations efficiently. Refer to `v4-docs/docs/guides/04-hooks/` for hook implementation patterns.

2. **Storage Pattern**: Uses mappings for loan storage with incremental IDs:
   - `loans`: Main loan storage (loanId => Loan)
   - `liquidationData`: Temporary storage during liquidation
   - `borrowerLoans`/`lenderLoans`: User loan tracking

3. **Security Considerations**:
   - Reentrancy protection on critical functions
   - Signature replay prevention via nonces
   - Access control for hook registration
   - Follow security guidelines in `v4-docs/docs/security/`

## Uniswap V4 Integration Guidelines

When implementing or modifying hook functionality:

1. **Reference Documentation**: Always check `v4-docs/` for:
   - Hook lifecycle and callback patterns
   - Pool manager interaction requirements
   - Best practices for gas optimization
   - Security considerations specific to v4

2. **Hook Implementation Checklist**:
   - [ ] Implement required hook callbacks (beforeSwap, afterSwap)
   - [ ] Register hook permissions correctly
   - [ ] Handle pool state changes appropriately
   - [ ] Test with various pool configurations
   - [ ] Verify gas consumption is within limits

3. **Testing with V4**:
   - Use fork tests against deployed v4 contracts
   - Test edge cases specific to hook mechanics
   - Verify liquidation flows through actual swaps
   - Ensure proper integration with PoolManager

## Testing Approach

The main test file `test/DebtProtocol.t.sol` covers:
- Complete loan lifecycle testing
- Edge cases for liquidation scenarios
- Order signature validation
- Integration with Uniswap v4 pools

When adding new functionality, follow the existing test patterns using Foundry's testing framework.

## Development Phases

### Phase 1: Core Contract Development
1. **Environment Setup**
   - Initialize Foundry project with dependencies
   - Configure Uniswap v4 core and periphery libraries
   - Set up Chainlink interfaces for price feeds
   - Configure remappings in foundry.toml

2. **DebtHook Implementation**
   - Define Loan struct with all necessary fields
   - Implement loan creation with collateral validation
   - Add repayment logic with interest calculation
   - Build liquidation mechanism using beforeSwap/afterSwap hooks
   - Integrate price oracles for health factor calculation

3. **DebtOrderBook Development**
   - Implement EIP-712 domain separator
   - Create LoanOrder struct and signing logic
   - Add order validation and execution
   - Implement nonce management for replay protection

4. **Comprehensive Testing**
   - Unit tests for each function
   - Integration tests with Uniswap v4 pools
   - Fork testing against mainnet state
   - Gas optimization and snapshots

### Phase 2: Deployment and Infrastructure
1. **Deployment Scripts**
   - Deploy MockERC20 tokens for testing
   - Deploy and initialize Uniswap v4 pools
   - Deploy DebtHook with proper configuration
   - Deploy DebtOrderBook with correct domain
   - Verify contracts on Etherscan

2. **Keeper Bot Development**
   - Monitor loan health factors
   - Execute liquidations when profitable
   - Integrate with Chainlink Automation

## Key Implementation Details

### Liquidation Mechanism
The protocol uses a unique two-phase liquidation through Uniswap v4:
1. **beforeSwap**: Identifies liquidatable positions, calculates amounts
2. **Swap Execution**: Uniswap swaps collateral to USDC
3. **afterSwap**: Distributes proceeds, updates loan state

### Storage Patterns
- Loans stored in mapping with auto-incrementing IDs
- Borrower/lender loan arrays for easy querying
- Temporary liquidation data during swap execution
- Efficient packing to minimize storage slots

### Security Considerations
1. **Reentrancy Protection**: Use checks-effects-interactions pattern
2. **Access Control**: Only registered hooks can call certain functions
3. **Signature Validation**: Prevent replay attacks with nonces
4. **Overflow Protection**: Solidity 0.8+ automatic checks
5. **Oracle Manipulation**: Use TWAP or multiple price sources

## Development Notes

1. **Hook Registration**: DebtHook must be properly registered with the PoolManager before use

2. **Price Oracles**: Currently uses mock prices. Production will integrate Chainlink oracles

3. **Liquidation Threshold**: Set at 150% collateralization ratio (health factor < 1.5 triggers liquidation)

4. **Gas Optimization**: The contract uses custom errors and efficient storage patterns. Continue this approach for new features

5. **Foundry Remappings**: Dependencies are remapped in `foundry.toml`:
   - `@uniswap/v4-core/` → `lib/v4-core/`
   - `@uniswap/v4-periphery/` → `lib/v4-periphery/`

6. **Testing Strategy**:
   - Use `forge coverage` to ensure >90% test coverage
   - Test edge cases: zero amounts, max values, precision loss
   - Simulate various market conditions in fork tests

7. **Deployment Checklist**:
   - [ ] All tests passing
   - [ ] Gas optimizations complete
   - [ ] Security review conducted
   - [ ] Deployment scripts tested on testnet
   - [ ] Contract verification prepared
