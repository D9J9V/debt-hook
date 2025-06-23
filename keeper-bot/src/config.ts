import dotenv from 'dotenv';

dotenv.config();

export const config = {
  // RPC and wallet
  rpcUrl: process.env.RPC_URL!,
  keeperPrivateKey: process.env.KEEPER_PRIVATE_KEY!,
  
  // Contract addresses
  contracts: {
    debtHook: process.env.DEBT_HOOK_ADDRESS!,
    usdc: process.env.USDC_ADDRESS || '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
    weth: process.env.WETH_ADDRESS || '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
    chainlinkEthUsd: process.env.CHAINLINK_ETH_USD_FEED || '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419',
  },
  
  // Supabase
  supabase: {
    url: process.env.SUPABASE_URL!,
    serviceRoleKey: process.env.SUPABASE_SERVICE_ROLE_KEY!,
  },
  
  // Bot parameters
  bot: {
    healthFactorThreshold: parseFloat(process.env.HEALTH_FACTOR_THRESHOLD || '1.2'),
    minProfitUsd: parseFloat(process.env.MIN_PROFIT_USD || '10'),
    checkIntervalSeconds: parseInt(process.env.CHECK_INTERVAL_SECONDS || '60'),
    gasPriceMultiplier: parseFloat(process.env.GAS_PRICE_MULTIPLIER || '1.2'),
  },
  
  // Monitoring
  discordWebhookUrl: process.env.DISCORD_WEBHOOK_URL,
};

// Validate required config
export function validateConfig() {
  const required = [
    'rpcUrl',
    'keeperPrivateKey',
    'contracts.debtHook',
    'supabase.url',
    'supabase.serviceRoleKey',
  ];
  
  for (const key of required) {
    const value = key.split('.').reduce((obj, k) => obj?.[k], config as any);
    if (!value) {
      throw new Error(`Missing required config: ${key}`);
    }
  }
}