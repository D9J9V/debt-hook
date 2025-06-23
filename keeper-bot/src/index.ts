import cron from 'node-cron';
import { config, validateConfig } from './config';
import { logger, notifyDiscord } from './logger';
import { Liquidator } from './liquidator';

async function main() {
  try {
    // Validate configuration
    validateConfig();
    logger.info('Keeper bot configuration validated');

    // Initialize liquidator
    const liquidator = new Liquidator();
    
    // Send startup notification
    await notifyDiscord(
      `🚀 Keeper bot started\n` +
      `Health Factor Threshold: ${config.bot.healthFactorThreshold}\n` +
      `Min Profit: $${config.bot.minProfitUsd}\n` +
      `Check Interval: ${config.bot.checkIntervalSeconds}s`,
      config.discordWebhookUrl
    );

    // Run initial check
    logger.info('Running initial liquidation check...');
    await liquidator.checkAndLiquidate();

    // Schedule regular checks
    const cronExpression = `*/${config.bot.checkIntervalSeconds} * * * * *`;
    cron.schedule(cronExpression, async () => {
      await liquidator.checkAndLiquidate();
    });

    logger.info(`Keeper bot running - checking every ${config.bot.checkIntervalSeconds} seconds`);

    // Handle graceful shutdown
    process.on('SIGINT', async () => {
      logger.info('Shutting down keeper bot...');
      await notifyDiscord('🛑 Keeper bot shutting down', config.discordWebhookUrl);
      process.exit(0);
    });

    process.on('SIGTERM', async () => {
      logger.info('Shutting down keeper bot...');
      await notifyDiscord('🛑 Keeper bot shutting down', config.discordWebhookUrl);
      process.exit(0);
    });

  } catch (error) {
    logger.error('Fatal error:', error);
    await notifyDiscord(
      `💀 Keeper bot crashed: ${error instanceof Error ? error.message : 'Unknown error'}`,
      config.discordWebhookUrl
    );
    process.exit(1);
  }
}

// Start the bot
main().catch((error) => {
  logger.error('Unhandled error:', error);
  process.exit(1);
});