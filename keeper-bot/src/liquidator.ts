import { ethers } from 'ethers';
import { createClient } from '@supabase/supabase-js';
import { config } from './config';
import { logger, notifyDiscord } from './logger';
import { DEBT_HOOK_ABI, CHAINLINK_FEED_ABI, ERC20_ABI } from './contracts';

export class Liquidator {
  private provider: ethers.Provider;
  private wallet: ethers.Wallet;
  private debtHook: ethers.Contract;
  private priceFeed: ethers.Contract;
  private supabase: ReturnType<typeof createClient>;

  constructor() {
    this.provider = new ethers.JsonRpcProvider(config.rpcUrl);
    this.wallet = new ethers.Wallet(config.keeperPrivateKey, this.provider);
    this.debtHook = new ethers.Contract(config.contracts.debtHook, DEBT_HOOK_ABI, this.wallet);
    this.priceFeed = new ethers.Contract(config.contracts.chainlinkEthUsd, CHAINLINK_FEED_ABI, this.provider);
    this.supabase = createClient(config.supabase.url, config.supabase.serviceRoleKey);
  }

  async checkAndLiquidate() {
    try {
      logger.info('Starting liquidation check...');

      // Get current ETH price
      const ethPrice = await this.getEthPrice();
      logger.info(`Current ETH price: $${ethPrice.toFixed(2)}`);

      // Get liquidatable loans from Supabase edge function
      const response = await fetch(`${config.supabase.url}/functions/v1/get-liquidatable-loans`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${config.supabase.serviceRoleKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          ethPrice,
          healthThreshold: config.bot.healthFactorThreshold,
        }),
      });

      if (!response.ok) {
        throw new Error(`Failed to fetch liquidatable loans: ${response.statusText}`);
      }

      const { liquidatableLoans } = await response.json();
      logger.info(`Found ${liquidatableLoans.length} liquidatable loans`);

      // Process each liquidatable loan
      for (const loan of liquidatableLoans) {
        await this.processLiquidation(loan, ethPrice);
      }

    } catch (error) {
      logger.error('Error in liquidation check:', error);
      await notifyDiscord(
        `❌ Liquidation check failed: ${error instanceof Error ? error.message : 'Unknown error'}`,
        config.discordWebhookUrl
      );
    }
  }

  private async getEthPrice(): Promise<number> {
    const { price } = await this.priceFeed.latestRoundData();
    const decimals = await this.priceFeed.decimals();
    return Number(price) / Math.pow(10, Number(decimals));
  }

  private async processLiquidation(loan: any, ethPrice: number) {
    try {
      logger.info(`Processing liquidation for loan ${loan.loanId}`);

      // Check if liquidation is still profitable
      const estimatedGas = 300000n; // Estimate for liquidation
      const gasPrice = await this.provider.getFeeData();
      const gasCost = estimatedGas * gasPrice.gasPrice! * BigInt(Math.floor(config.bot.gasPriceMultiplier * 100)) / 100n;
      const gasCostUsd = Number(gasCost) / 1e18 * ethPrice;

      // Calculate expected profit
      const collateralValueUsd = parseFloat(loan.collateralValueUsd);
      const debtValueUsd = parseFloat(loan.debtValueUsd);
      const liquidationBonus = collateralValueUsd * 0.05; // 5% bonus
      const expectedProfit = liquidationBonus - gasCostUsd;

      if (expectedProfit < config.bot.minProfitUsd) {
        logger.warn(`Skipping loan ${loan.loanId}: Expected profit $${expectedProfit.toFixed(2)} below minimum`);
        return;
      }

      // Check wallet balance
      const balance = await this.provider.getBalance(this.wallet.address);
      if (balance < gasCost * 2n) { // Require 2x gas cost for safety
        logger.error('Insufficient ETH balance for liquidation');
        await notifyDiscord(
          `⚠️ Low ETH balance: ${ethers.formatEther(balance)} ETH`,
          config.discordWebhookUrl
        );
        return;
      }

      // Execute liquidation
      logger.info(`Executing liquidation for loan ${loan.loanId}...`);
      const tx = await this.debtHook.liquidate(loan.loanId, {
        gasLimit: estimatedGas,
        gasPrice: gasPrice.gasPrice! * BigInt(Math.floor(config.bot.gasPriceMultiplier * 100)) / 100n,
      });

      logger.info(`Liquidation transaction sent: ${tx.hash}`);
      const receipt = await tx.wait();

      if (receipt.status === 1) {
        logger.info(`✅ Liquidation successful for loan ${loan.loanId}`);
        await notifyDiscord(
          `✅ Liquidated loan ${loan.loanId}\n` +
          `Health Factor: ${loan.healthFactor}\n` +
          `Profit: $${expectedProfit.toFixed(2)}\n` +
          `Tx: ${tx.hash}`,
          config.discordWebhookUrl
        );

        // Update loan status in Supabase
        await this.updateLoanStatus(loan.loanId, 'liquidated', tx.hash);
      } else {
        logger.error(`Liquidation failed for loan ${loan.loanId}`);
      }

    } catch (error) {
      logger.error(`Error processing liquidation for loan ${loan.loanId}:`, error);
      
      // Check if it's a revert error
      if (error instanceof Error && error.message.includes('revert')) {
        logger.warn(`Liquidation reverted - loan ${loan.loanId} may no longer be liquidatable`);
      }
    }
  }

  private async updateLoanStatus(loanId: string, status: string, txHash: string) {
    try {
      const response = await fetch(`${config.supabase.url}/functions/v1/update-loan-status`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${config.supabase.serviceRoleKey}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          eventType: 'LoanLiquidated',
          data: {
            loanId,
            status,
            transactionHash: txHash,
            blockNumber: await this.provider.getBlockNumber(),
            timestamp: Math.floor(Date.now() / 1000),
          },
        }),
      });

      if (!response.ok) {
        logger.error(`Failed to update loan status: ${response.statusText}`);
      }
    } catch (error) {
      logger.error('Error updating loan status:', error);
    }
  }
}