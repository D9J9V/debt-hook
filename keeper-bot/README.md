# DebtHook Keeper Bot

Automated liquidation bot for the DebtHook protocol. Monitors active loans and executes liquidations when positions become undercollateralized.

## Features

- **Real-time Monitoring**: Continuously monitors loan health factors
- **Profitable Liquidations**: Only executes liquidations when profitable after gas costs
- **Supabase Integration**: Fetches loan data and updates statuses via edge functions
- **Price Feed Integration**: Uses Chainlink oracles for accurate ETH/USD pricing
- **Discord Notifications**: Sends alerts for liquidations and errors
- **Configurable Parameters**: Adjustable health factor threshold, minimum profit, and check intervals

## Setup

1. Install dependencies:
```bash
npm install
```

2. Copy `.env.example` to `.env` and configure:
```bash
cp .env.example .env
```

3. Required environment variables:
- `RPC_URL`: Ethereum RPC endpoint
- `KEEPER_PRIVATE_KEY`: Private key for the keeper wallet
- `DEBT_HOOK_ADDRESS`: DebtHook contract address
- `SUPABASE_URL`: Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY`: Supabase service role key

## Running the Bot

### Development
```bash
npm run dev
```

### Production
```bash
npm run build
npm start
```

## Configuration

### Bot Parameters

- `HEALTH_FACTOR_THRESHOLD`: Liquidate loans below this health factor (default: 1.2)
- `MIN_PROFIT_USD`: Minimum profit required to execute liquidation (default: $10)
- `CHECK_INTERVAL_SECONDS`: How often to check for liquidations (default: 60s)
- `GAS_PRICE_MULTIPLIER`: Multiplier for gas price to ensure transaction success (default: 1.2)

### Monitoring

- `DISCORD_WEBHOOK_URL`: Optional webhook for notifications

## How It Works

1. **Price Fetching**: Gets current ETH price from Chainlink oracle
2. **Loan Scanning**: Queries Supabase for active loans via edge function
3. **Health Calculation**: Determines which loans are liquidatable based on collateral value vs debt
4. **Profitability Check**: Calculates expected profit after gas costs
5. **Liquidation Execution**: Calls `liquidate()` on the DebtHook contract
6. **Status Update**: Updates loan status in Supabase after successful liquidation

## Security Considerations

- Keep your private key secure - never commit it to version control
- Monitor the keeper wallet balance to ensure sufficient ETH for gas
- Set appropriate minimum profit to avoid unprofitable liquidations
- Use a dedicated wallet for the keeper bot

## Deployment

### Using PM2

```bash
npm run build
pm2 start dist/index.js --name debt-hook-keeper
```

### Using Docker

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build
CMD ["node", "dist/index.js"]
```

## Monitoring

The bot logs all activities and can send Discord notifications for:
- Bot startup/shutdown
- Successful liquidations
- Errors and failures
- Low wallet balance warnings

Check logs in:
- `combined.log`: All logs
- `error.log`: Error logs only
- Console output in development mode