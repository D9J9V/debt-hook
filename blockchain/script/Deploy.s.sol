// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {DebtHook} from "../src/DebtHook.sol";
import {DebtOrderBook} from "../src/DebtOrderBook.sol";
import {IPriceFeed} from "../src/interfaces/IPriceFeed.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";

/// @title Deploy Script
/// @notice Deploys the DebtProtocol system to testnet
contract Deploy is Script {
    // Unichain Sepolia addresses
    address constant WETH = address(0); // Native ETH
    address constant POOL_MANAGER = address(0); // Deploy new or use existing
    address constant CHAINLINK_ETH_USD = 0xd9c93081210dFc33326B2af4C2c11848095E6a9a; // ETH/USD on Unichain Sepolia
    
    // Pool configuration
    uint24 constant POOL_FEE = 3000; // 0.3%
    int24 constant TICK_SPACING = 60;
    uint160 constant SQRT_PRICE_1_1 = 79228162514264337593543950336;
    
    // Protocol configuration
    address treasury;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0));
        address deployer;
        if (deployerPrivateKey == 0) {
            // If no env var, script will use the private key from command line
            deployer = msg.sender;
        } else {
            deployer = vm.addr(deployerPrivateKey);
        }
        treasury = vm.envOr("TREASURY", deployer);
        
        console.log("Deploying from:", deployer);
        console.log("Treasury:", treasury);
        
        if (deployerPrivateKey == 0) {
            vm.startBroadcast();
        } else {
            vm.startBroadcast(deployerPrivateKey);
        }
        
        // 1. Deploy PoolManager if needed
        IPoolManager poolManager;
        if (POOL_MANAGER == address(0)) {
            poolManager = IPoolManager(address(new PoolManager(deployer)));
            console.log("PoolManager deployed:", address(poolManager));
        } else {
            poolManager = IPoolManager(POOL_MANAGER);
            console.log("Using existing PoolManager:", address(poolManager));
        }
        
        // 2. Deploy USDC mock (for testnet)
        MockERC20 usdc = new MockERC20("USD Coin", "USDC", 6);
        console.log("USDC deployed:", address(usdc));
        
        // 3. Use Chainlink price feed
        IPriceFeed priceFeed = IPriceFeed(CHAINLINK_ETH_USD);
        console.log("Using Chainlink ETH/USD price feed:", address(priceFeed));
        
        // 4. Deploy DebtHook with placeholder orderBook
        DebtHook debtHook = new DebtHook(
            poolManager,
            address(priceFeed),
            address(1), // Placeholder orderBook
            treasury,
            Currency.wrap(WETH),
            Currency.wrap(address(usdc)),
            POOL_FEE,
            TICK_SPACING
        );
        console.log("DebtHook deployed:", address(debtHook));
        
        // 5. Deploy DebtOrderBook
        DebtOrderBook orderBook = new DebtOrderBook(
            address(debtHook),
            address(usdc)
        );
        console.log("DebtOrderBook deployed:", address(orderBook));
        
        // 6. Redeploy DebtHook with correct orderBook address
        debtHook = new DebtHook(
            poolManager,
            address(priceFeed),
            address(orderBook),
            treasury,
            Currency.wrap(WETH),
            Currency.wrap(address(usdc)),
            POOL_FEE,
            TICK_SPACING
        );
        console.log("DebtHook redeployed:", address(debtHook));
        
        // 7. Redeploy DebtOrderBook with correct DebtHook address
        orderBook = new DebtOrderBook(
            address(debtHook),
            address(usdc)
        );
        console.log("DebtOrderBook redeployed:", address(orderBook));
        
        // 8. Initialize pool
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(WETH),
            currency1: Currency.wrap(address(usdc)),
            fee: POOL_FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(0))
        });
        
        poolManager.initialize(key, SQRT_PRICE_1_1);
        console.log("Pool initialized");
        
        // 9. Output deployment summary
        console.log("\n=== Deployment Summary ===");
        console.log("Network:", block.chainid);
        console.log("PoolManager:", address(poolManager));
        console.log("USDC:", address(usdc));
        console.log("PriceFeed:", address(priceFeed));
        console.log("DebtHook:", address(debtHook));
        console.log("DebtOrderBook:", address(orderBook));
        console.log("Treasury:", treasury);
        
        vm.stopBroadcast();
        
        // Output deployment JSON format for easy copying
        console.log("\n=== Deployment JSON ===");
        console.log("{");
        console.log('  "chainId":', block.chainid, ',');
        console.log('  "poolManager": "', address(poolManager), '",');
        console.log('  "usdc": "', address(usdc), '",');
        console.log('  "priceFeed": "', address(priceFeed), '",');
        console.log('  "debtHook": "', address(debtHook), '",');
        console.log('  "debtOrderBook": "', address(orderBook), '",');
        console.log('  "treasury": "', treasury, '"');
        console.log("}");
    }
}