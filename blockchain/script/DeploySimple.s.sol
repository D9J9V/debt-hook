// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {DebtHook} from "../src/DebtHook.sol";
import {DebtOrderBook} from "../src/DebtOrderBook.sol";
import {ChainlinkPriceFeed} from "../src/ChainlinkPriceFeed.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";

/// @title Simple Deploy Script
/// @notice Deploys the DebtProtocol without hook address mining (for testing)
contract DeploySimple is Script {
    // Unichain Sepolia addresses
    address constant WETH = address(0); // Native ETH
    address constant CHAINLINK_ETH_USD = 0xd9c93081210dFc33326B2af4C2c11848095E6a9a;

    // Pool configuration
    uint24 constant POOL_FEE = 3000; // 0.3%
    int24 constant TICK_SPACING = 60;
    uint160 constant SQRT_PRICE_1_1 = 79228162514264337593543950336;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address treasury = vm.envOr("TREASURY", deployer);

        console.log("=== DebtProtocol Simple Deployment ===");
        console.log("Deployer:", deployer);
        console.log("Treasury:", treasury);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy PoolManager
        PoolManager poolManager = new PoolManager(deployer);
        console.log("PoolManager deployed:", address(poolManager));

        // 2. Deploy USDC mock
        MockERC20 usdc = new MockERC20("USD Coin", "USDC", 6);
        console.log("USDC deployed:", address(usdc));

        // 3. Deploy price feed wrapper
        ChainlinkPriceFeed priceFeed = new ChainlinkPriceFeed(CHAINLINK_ETH_USD);
        console.log("PriceFeed deployed:", address(priceFeed));

        // 4. Deploy contracts with circular dependency resolution
        // First deploy with placeholder
        DebtHook debtHook = new DebtHook(
            IPoolManager(address(poolManager)),
            address(priceFeed),
            address(1), // placeholder
            treasury,
            Currency.wrap(WETH),
            Currency.wrap(address(usdc)),
            POOL_FEE,
            TICK_SPACING
        );
        console.log("DebtHook (temp) deployed:", address(debtHook));

        // Deploy OrderBook
        DebtOrderBook orderBook = new DebtOrderBook(address(debtHook), address(usdc));
        console.log("DebtOrderBook deployed:", address(orderBook));

        // Redeploy DebtHook with correct orderBook
        debtHook = new DebtHook(
            IPoolManager(address(poolManager)),
            address(priceFeed),
            address(orderBook),
            treasury,
            Currency.wrap(WETH),
            Currency.wrap(address(usdc)),
            POOL_FEE,
            TICK_SPACING
        );
        console.log("DebtHook (final) deployed:", address(debtHook));

        // Final OrderBook deployment
        orderBook = new DebtOrderBook(address(debtHook), address(usdc));
        console.log("DebtOrderBook (final) deployed:", address(orderBook));

        // 5. Initialize pool
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(WETH),
            currency1: Currency.wrap(address(usdc)),
            fee: POOL_FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(0))
        });

        poolManager.initialize(key, SQRT_PRICE_1_1);
        console.log("Pool initialized");

        // 6. Mint some USDC for testing
        usdc.mint(deployer, 1_000_000 * 1e6); // 1M USDC
        console.log("Minted 1M USDC to deployer");

        vm.stopBroadcast();

        // Output deployment summary
        console.log("\n=== Deployment Summary ===");
        console.log("Network: Unichain Sepolia");
        console.log("Chain ID:", block.chainid);
        console.log("PoolManager:", address(poolManager));
        console.log("USDC:", address(usdc));
        console.log("PriceFeed:", address(priceFeed));
        console.log("DebtHook:", address(debtHook));
        console.log("DebtOrderBook:", address(orderBook));
        console.log("Treasury:", treasury);
        
        console.log("\nWARNING: This deployment does not use proper hook address mining!");
        console.log("For production deployment, use DeployHook.s.sol or DeployHookOptimized.s.sol");
        
        // Output for easy copying
        console.log("\n=== Copy for .env ===");
        console.log("NEXT_PUBLIC_POOL_MANAGER=", address(poolManager));
        console.log("NEXT_PUBLIC_USDC_ADDRESS=", address(usdc));
        console.log("NEXT_PUBLIC_DEBT_HOOK=", address(debtHook));
        console.log("NEXT_PUBLIC_DEBT_ORDER_BOOK=", address(orderBook));
    }
}