// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";
import {DebtHookOptimized} from "../src/DebtHookOptimized.sol";
import {DebtOrderBook} from "../src/DebtOrderBook.sol";
import {ChainlinkPriceFeed} from "../src/ChainlinkPriceFeed.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";

contract DeployHookOptimized is Script {
    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);
    address constant WETH = address(0);
    address constant CHAINLINK_ETH_USD = 0xd9c93081210dFc33326B2af4C2c11848095E6a9a;
    address constant OPERATOR = 0x2f131a86C5CB54685f0E940B920c54E152a44B02;
    
    uint24 constant POOL_FEE = 3000;
    int24 constant TICK_SPACING = 60;
    uint160 constant SQRT_PRICE_1_1 = 79228162514264337593543950336;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address treasury = deployer; // Using deployer as treasury

        console.log("=== DebtHook Optimized Deployment ===");
        console.log("Deployer:", deployer);
        console.log("Operator to authorize:", OPERATOR);

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

        // 4. Define hook permissions
        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | 
            Hooks.AFTER_SWAP_FLAG | 
            Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );

        // 5. First deploy with placeholder OrderBook
        address placeholderOrderBook = address(1);
        bytes memory constructorArgs = abi.encode(
            poolManager,
            address(priceFeed),
            placeholderOrderBook,
            treasury,
            Currency.wrap(WETH),
            Currency.wrap(address(usdc)),
            POOL_FEE,
            TICK_SPACING
        );

        // 6. Mine hook address
        console.log("Mining hook address...");
        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            flags,
            type(DebtHookOptimized).creationCode,
            constructorArgs
        );
        console.log("Found hook address:", hookAddress);

        // 7. Deploy DebtHook
        DebtHookOptimized debtHook = new DebtHookOptimized{salt: salt}(
            IPoolManager(address(poolManager)),
            address(priceFeed),
            placeholderOrderBook,
            treasury,
            Currency.wrap(WETH),
            Currency.wrap(address(usdc)),
            POOL_FEE,
            TICK_SPACING
        );
        require(address(debtHook) == hookAddress, "Hook address mismatch!");
        console.log("DebtHook deployed:", address(debtHook));

        // 8. Deploy OrderBook
        DebtOrderBook orderBook = new DebtOrderBook(address(debtHook), address(usdc));
        console.log("DebtOrderBook deployed:", address(orderBook));

        // 9. Now redeploy hook with correct OrderBook
        constructorArgs = abi.encode(
            poolManager,
            address(priceFeed),
            address(orderBook),
            treasury,
            Currency.wrap(WETH),
            Currency.wrap(address(usdc)),
            POOL_FEE,
            TICK_SPACING
        );

        console.log("Mining final hook address...");
        (hookAddress, salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            flags,
            type(DebtHookOptimized).creationCode,
            constructorArgs
        );

        // 10. Deploy final DebtHook
        debtHook = new DebtHookOptimized{salt: salt}(
            IPoolManager(address(poolManager)),
            address(priceFeed),
            address(orderBook),
            treasury,
            Currency.wrap(WETH),
            Currency.wrap(address(usdc)),
            POOL_FEE,
            TICK_SPACING
        );
        console.log("Final DebtHook deployed:", address(debtHook));

        // 11. Redeploy OrderBook pointing to final hook
        orderBook = new DebtOrderBook(address(debtHook), address(usdc));
        console.log("Final DebtOrderBook deployed:", address(orderBook));

        // 12. Authorize operator
        console.log("Authorizing operator...");
        debtHook.authorizeOperator(OPERATOR, true);
        console.log("Operator authorized!");

        // 13. Initialize pool
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(WETH),
            currency1: Currency.wrap(address(usdc)),
            fee: POOL_FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(0))
        });

        poolManager.initialize(key, SQRT_PRICE_1_1);
        console.log("Pool initialized");

        // 14. Set ServiceManager on OrderBook
        address serviceManager = vm.envOr("SERVICE_MANAGER_ADDRESS", address(0));
        if (serviceManager != address(0)) {
            console.log("Setting ServiceManager:", serviceManager);
            orderBook.setServiceManager(serviceManager);
        }

        vm.stopBroadcast();

        // Output summary
        console.log("\n=== Deployment Summary ===");
        console.log("PoolManager:", address(poolManager));
        console.log("DebtHook:", address(debtHook));
        console.log("DebtOrderBook:", address(orderBook));
        console.log("USDC:", address(usdc));
        console.log("PriceFeed:", address(priceFeed));
        console.log("Operator Authorized:", OPERATOR);
    }
}