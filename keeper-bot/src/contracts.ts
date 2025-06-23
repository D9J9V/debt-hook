import { ethers } from 'ethers';

// DebtHook ABI (minimal - only liquidation function)
export const DEBT_HOOK_ABI = [
  'function liquidate(uint256 loanId) external',
  'function loans(uint256) view returns (address lender, address borrower, address collateralToken, address loanToken, uint256 loanAmount, uint256 collateralAmount, uint256 ratePerSecond, uint256 startTime, uint256 duration, bool isActive)',
  'event LoanLiquidated(uint256 indexed loanId, address indexed liquidator, uint256 collateralAmount, uint256 debtAmount)',
];

// Chainlink Price Feed ABI
export const CHAINLINK_FEED_ABI = [
  'function latestRoundData() view returns (uint80 roundId, int256 price, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)',
  'function decimals() view returns (uint8)',
];

// ERC20 ABI (for balance checks)
export const ERC20_ABI = [
  'function balanceOf(address) view returns (uint256)',
  'function allowance(address owner, address spender) view returns (uint256)',
  'function approve(address spender, uint256 amount) returns (bool)',
];