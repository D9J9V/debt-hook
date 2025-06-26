#!/usr/bin/env node

const { createWalletClient, createPublicClient, http, parseEther, parseUnits } = require('viem');
const { privateKeyToAccount } = require('viem/accounts');
const { unichain_sepolia } = require('viem/chains');

// ABIs (simplified - add full ABIs from your contracts)
const DEBT_ORDER_BOOK_ABI = [
  {
    "name": "submitOrderToAVS",
    "type": "function",
    "inputs": [
      { "name": "order", "type": "tuple", "components": [
        { "name": "lender", "type": "address" },
        { "name": "token", "type": "address" },
        { "name": "principalAmount", "type": "uint256" },
        { "name": "collateralRequired", "type": "uint256" },
        { "name": "interestRateBips", "type": "uint32" },
        { "name": "maturityTimestamp", "type": "uint64" },
        { "name": "expiry", "type": "uint64" },
        { "name": "nonce", "type": "uint256" }
      ]},
      { "name": "signature", "type": "bytes" },
      { "name": "minPrincipal", "type": "uint256" },
      { "name": "maxPrincipal", "type": "uint256" },
      { "name": "minRate", "type": "uint256" },
      { "name": "maxRate", "type": "uint256" }
    ]
  },
  {
    "name": "submitBorrowerOrderToAVS",
    "type": "function",
    "inputs": [
      { "name": "principalAmount", "type": "uint256" },
      { "name": "maxInterestRateBips", "type": "uint256" },
      { "name": "maturityTimestamp", "type": "uint256" },
      { "name": "collateralAmount", "type": "uint256" },
      { "name": "minPrincipal", "type": "uint256" },
      { "name": "maxPrincipal", "type": "uint256" },
      { "name": "expiry", "type": "uint256" }
    ]
  }
];

async function main() {
  // Configuration
  const DEBT_ORDER_BOOK_ADDRESS = process.env.DEBT_ORDER_BOOK_ADDRESS;
  const USDC_ADDRESS = process.env.USDC_ADDRESS;
  const PRIVATE_KEY = process.env.PRIVATE_KEY;
  const RPC_URL = process.env.UNICHAIN_RPC_URL || 'https://sepolia.unichain.org';
  
  if (!DEBT_ORDER_BOOK_ADDRESS || !PRIVATE_KEY) {
    console.error('Please set DEBT_ORDER_BOOK_ADDRESS and PRIVATE_KEY environment variables');
    process.exit(1);
  }

  // Setup clients
  const account = privateKeyToAccount(PRIVATE_KEY);
  const walletClient = createWalletClient({
    account,
    chain: unichain_sepolia,
    transport: http(RPC_URL)
  });
  
  const publicClient = createPublicClient({
    chain: unichain_sepolia,
    transport: http(RPC_URL)
  });

  console.log('Testing EigenLayer AVS Integration...');
  console.log('Account:', account.address);
  
  // Test 1: Submit a lender order
  console.log('\n1. Submitting lender order to AVS...');
  
  const lenderOrder = {
    lender: account.address,
    token: USDC_ADDRESS,
    principalAmount: parseUnits('1000', 6), // 1000 USDC
    collateralRequired: parseEther('1.5'), // 1.5 ETH
    interestRateBips: 500, // 5%
    maturityTimestamp: Math.floor(Date.now() / 1000) + 30 * 24 * 60 * 60, // 30 days
    expiry: Math.floor(Date.now() / 1000) + 7 * 24 * 60 * 60, // 7 days
    nonce: Date.now()
  };
  
  // Sign the order (simplified - use proper EIP-712 signing in production)
  const orderHash = keccak256(encodeAbiParameters(
    /* order type definition */
    lenderOrder
  ));
  const signature = await account.signMessage({ message: orderHash });
  
  try {
    const lenderTx = await walletClient.writeContract({
      address: DEBT_ORDER_BOOK_ADDRESS,
      abi: DEBT_ORDER_BOOK_ABI,
      functionName: 'submitOrderToAVS',
      args: [
        lenderOrder,
        signature,
        parseUnits('500', 6), // minPrincipal: 500 USDC
        parseUnits('2000', 6), // maxPrincipal: 2000 USDC
        400, // minRate: 4%
        600  // maxRate: 6%
      ]
    });
    
    console.log('Lender order submitted:', lenderTx);
    await publicClient.waitForTransactionReceipt({ hash: lenderTx });
    
  } catch (error) {
    console.error('Failed to submit lender order:', error);
  }
  
  // Test 2: Submit a borrower order
  console.log('\n2. Submitting borrower order to AVS...');
  
  try {
    const borrowerTx = await walletClient.writeContract({
      address: DEBT_ORDER_BOOK_ADDRESS,
      abi: DEBT_ORDER_BOOK_ABI,
      functionName: 'submitBorrowerOrderToAVS',
      args: [
        parseUnits('1000', 6), // principalAmount: 1000 USDC
        600, // maxInterestRateBips: 6%
        Math.floor(Date.now() / 1000) + 30 * 24 * 60 * 60, // maturity: 30 days
        parseEther('1.5'), // collateralAmount: 1.5 ETH
        parseUnits('800', 6), // minPrincipal: 800 USDC
        parseUnits('1200', 6), // maxPrincipal: 1200 USDC
        Math.floor(Date.now() / 1000) + 7 * 24 * 60 * 60 // expiry: 7 days
      ]
    });
    
    console.log('Borrower order submitted:', borrowerTx);
    await publicClient.waitForTransactionReceipt({ hash: borrowerTx });
    
  } catch (error) {
    console.error('Failed to submit borrower order:', error);
  }
  
  console.log('\n3. Orders submitted! Monitor operator logs for matching...');
  console.log('The operator should detect these orders and match them within 10 blocks.');
}

// Helper function (implement proper EIP-712 signing)
function keccak256(data) {
  // Implement keccak256 hashing
  return '0x' + '0'.repeat(64); // Placeholder
}

function encodeAbiParameters(types, values) {
  // Implement ABI encoding
  return '0x'; // Placeholder
}

main().catch(console.error);