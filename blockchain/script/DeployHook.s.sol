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
import {DebtHook} from "../src/DebtHook.sol";
import {DebtOrderBook} from "../src/DebtOrderBook.sol";
import {ChainlinkPriceFeed} from "../src/ChainlinkPriceFeed.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";

/// @title Deploy Hook Script
/// @notice Mines and deploys the DebtHook to a specific address with required permissions
contract DeployHook is Script {
    // CREATE2 Deployer Proxy - available on most chains
    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

    // Unichain Sepolia addresses
    address constant WETH = address(0); // Native ETH
    address constant CHAINLINK_ETH_USD = 0xd9c93081210dFc33326B2af4C2c11848095E6a9a;

    // Pool configuration
    uint24 constant POOL_FEE = 3000; // 0.3%
    int24 constant TICK_SPACING = 60;
    uint160 constant SQRT_PRICE_1_1 = 79228162514264337593543950336;

    function run() external {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0));
        address deployer;
        if (deployerPrivateKey == 0) {
            // If no env var, script will use the private key from command line
            deployer = msg.sender;
        } else {
            deployer = vm.addr(deployerPrivateKey);
        }
        address treasury = vm.envOr("TREASURY", deployer);

        console.log("=== DebtHook Deployment ===");
        console.log("Deployer:", deployer);
        console.log("Treasury:", treasury);
        console.log("CREATE2 Deployer:", CREATE2_DEPLOYER);

        if (deployerPrivateKey == 0) {
            vm.startBroadcast();
        } else {
            vm.startBroadcast(deployerPrivateKey);
        }

        // 1. Deploy PoolManager
        PoolManager poolManager = new PoolManager(deployer);
        console.log("PoolManager deployed:", address(poolManager));

        // 2. Deploy USDC mock (for testnet)
        MockERC20 usdc = new MockERC20("USD Coin", "USDC", 6);
        console.log("USDC deployed:", address(usdc));

        // 3. Setup price feed wrapper
        ChainlinkPriceFeed priceFeed = new ChainlinkPriceFeed(CHAINLINK_ETH_USD);
        console.log("PriceFeed deployed:", address(priceFeed));

        // 4. Define hook permissions
        // BEFORE_SWAP_FLAG = 0x80
        // AFTER_SWAP_FLAG = 0x40
        // BEFORE_SWAP_RETURNS_DELTA_FLAG = 0x08
        // Combined: 0x80 | 0x40 | 0x08 = 0xC8
        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | 
            Hooks.AFTER_SWAP_FLAG | 
            Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );
        console.log("Hook flags:", vm.toString(flags));

        // 5. Prepare constructor arguments for hook
        // We'll use a placeholder for orderBook address
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

        // 6. Mine a salt for the hook address
        console.log("Mining hook address with flags...");
        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            flags,
            type(DebtHook).creationCode,
            constructorArgs
        );
        console.log("Found hook address:", hookAddress);
        console.log("Salt:", vm.toString(salt));

        // 7. Deploy DebtHook to the mined address
        DebtHook debtHook = new DebtHook{salt: salt}(
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
        console.log("DebtHook deployed to mined address:", address(debtHook));

        // 8. Deploy DebtOrderBook with the correct hook address
        DebtOrderBook orderBook = new DebtOrderBook(address(debtHook), address(usdc));
        console.log("DebtOrderBook deployed:", address(orderBook));

        // 9. Now we need to redeploy the hook with the correct orderBook address
        // This requires mining a new address with the correct constructor args
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
            type(DebtHook).creationCode,
            constructorArgs
        );
        console.log("Found final hook address:", hookAddress);
        console.log("Salt:", vm.toString(salt));

        // 10. Deploy final DebtHook
        debtHook = new DebtHook{salt: salt}(
            IPoolManager(address(poolManager)),
            address(priceFeed),
            address(orderBook),
            treasury,
            Currency.wrap(WETH),
            Currency.wrap(address(usdc)),
            POOL_FEE,
            TICK_SPACING
        );
        require(address(debtHook) == hookAddress, "Final hook address mismatch!");
        console.log("Final DebtHook deployed:", address(debtHook));

        // 11. Redeploy OrderBook to point to the final hook
        orderBook = new DebtOrderBook(address(debtHook), address(usdc));
        console.log("Final DebtOrderBook deployed:", address(orderBook));

        // 12. Initialize the pool
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(WETH),
            currency1: Currency.wrap(address(usdc)),
            fee: POOL_FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(0)) // No hooks for the liquidation pool
        });

        poolManager.initialize(key, SQRT_PRICE_1_1);
        console.log("Pool initialized");

        // 13. Output deployment summary
        console.log("\n=== Deployment Summary ===");
        console.log("Network: Unichain Sepolia");
        console.log("Chain ID:", block.chainid);
        console.log("PoolManager:", address(poolManager));
        console.log("USDC:", address(usdc));
        console.log("PriceFeed:", address(priceFeed));
        console.log("DebtHook:", address(debtHook));
        console.log("DebtOrderBook:", address(orderBook));
        console.log("Treasury:", treasury);
        console.log("\nHook Address Info:");
        console.log("Address:", hookAddress);
        console.log("Flags (binary):", _toBinary(uint160(hookAddress) & Hooks.ALL_HOOK_MASK));
        console.log("Expected flags:", _toBinary(flags));

        vm.stopBroadcast();

        // Output deployment JSON
        console.log("\n=== Deployment JSON ===");
        console.log("{");
        console.log('  "chainId": 1301,');
        console.log('  "poolManager": "', address(poolManager), '",');
        console.log('  "usdc": "', address(usdc), '",');
        console.log('  "priceFeed": "', address(priceFeed), '",');
        console.log('  "debtHook": "', address(debtHook), '",');
        console.log('  "debtOrderBook": "', address(orderBook), '",');
        console.log('  "treasury": "', treasury, '"');
        console.log("}");
    }

    function _toBinary(uint160 value) internal pure returns (string memory) {
        bytes memory result = new bytes(14);
        for (uint256 i = 0; i < 14; i++) {
            result[13 - i] = (value & (1 << i)) != 0 ? bytes1("1") : bytes1("0");
        }
        return string(result);
    }
}