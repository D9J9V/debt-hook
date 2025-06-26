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
// Removed Create2 import - using custom implementation

/// @title Deploy Hook Optimized Script
/// @notice Mines and deploys the DebtHook system with proper address resolution
contract DeployHookOptimized is Script {
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
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address treasury = vm.envOr("TREASURY", deployer);

        console.log("=== DebtHook Deployment (Optimized) ===");
        console.log("Deployer:", deployer);
        console.log("Treasury:", treasury);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy base infrastructure
        PoolManager poolManager = new PoolManager(deployer);
        console.log("PoolManager deployed:", address(poolManager));

        MockERC20 usdc = new MockERC20("USD Coin", "USDC", 6);
        console.log("USDC deployed:", address(usdc));

        ChainlinkPriceFeed priceFeed = new ChainlinkPriceFeed(CHAINLINK_ETH_USD);
        console.log("PriceFeed deployed:", address(priceFeed));

        // 2. Calculate DebtOrderBook address (will be deployed with CREATE2)
        bytes32 orderBookSalt = bytes32(uint256(1));
        address predictedOrderBookAddress = _computeCreate2Address(
            deployer,
            orderBookSalt,
            type(DebtOrderBook).creationCode,
            abi.encode(address(0), address(usdc)) // placeholder hook address
        );

        // 3. Define hook permissions
        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | 
            Hooks.AFTER_SWAP_FLAG | 
            Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );
        console.log("Hook flags:", vm.toString(flags));

        // 4. Mine hook address with the predicted orderBook address
        bytes memory hookConstructorArgs = abi.encode(
            poolManager,
            address(priceFeed),
            predictedOrderBookAddress,
            treasury,
            Currency.wrap(WETH),
            Currency.wrap(address(usdc)),
            POOL_FEE,
            TICK_SPACING
        );

        console.log("Mining hook address...");
        (address hookAddress, bytes32 hookSalt) = HookMiner.find(
            deployer, // Using deployer instead of CREATE2_DEPLOYER for simplicity
            flags,
            type(DebtHook).creationCode,
            hookConstructorArgs
        );
        console.log("Found hook address:", hookAddress);
        console.log("Hook salt:", vm.toString(hookSalt));

        // 5. Deploy DebtHook to mined address
        DebtHook debtHook = new DebtHook{salt: hookSalt}(
            IPoolManager(address(poolManager)),
            address(priceFeed),
            predictedOrderBookAddress,
            treasury,
            Currency.wrap(WETH),
            Currency.wrap(address(usdc)),
            POOL_FEE,
            TICK_SPACING
        );
        require(address(debtHook) == hookAddress, "Hook address mismatch!");
        console.log("DebtHook deployed:", address(debtHook));

        // 6. Now deploy DebtOrderBook with CREATE2 at the predicted address
        DebtOrderBook orderBook = new DebtOrderBook{salt: orderBookSalt}(
            address(debtHook),
            address(usdc)
        );
        require(address(orderBook) == predictedOrderBookAddress, "OrderBook address mismatch!");
        console.log("DebtOrderBook deployed:", address(orderBook));

        // 7. Initialize the pool
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(WETH),
            currency1: Currency.wrap(address(usdc)),
            fee: POOL_FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(0)) // No hooks for the liquidation pool
        });

        poolManager.initialize(key, SQRT_PRICE_1_1);
        console.log("Pool initialized");

        // 8. Verify hook permissions
        uint160 actualFlags = uint160(hookAddress) & Hooks.ALL_HOOK_MASK;
        require(actualFlags == flags, "Hook permissions mismatch!");
        console.log("Hook permissions verified");

        // 9. Output deployment summary
        console.log("\n=== Deployment Summary ===");
        console.log("Network: Unichain Sepolia");
        console.log("Chain ID:", block.chainid);
        console.log("PoolManager:", address(poolManager));
        console.log("USDC:", address(usdc));
        console.log("PriceFeed:", address(priceFeed));
        console.log("DebtHook:", address(debtHook));
        console.log("DebtOrderBook:", address(orderBook));
        console.log("Treasury:", treasury);
        
        console.log("\nHook Verification:");
        console.log("Expected flags:", _toBinary(flags));
        console.log("Actual flags:", _toBinary(actualFlags));
        console.log("Permissions match:", actualFlags == flags);

        vm.stopBroadcast();

        // Output deployment JSON
        _outputDeploymentJson(
            address(poolManager),
            address(usdc),
            address(priceFeed),
            address(debtHook),
            address(orderBook),
            treasury
        );
    }

    function _computeCreate2Address(
        address deployer,
        bytes32 salt,
        bytes memory creationCode,
        bytes memory constructorArgs
    ) internal pure returns (address) {
        bytes memory bytecode = abi.encodePacked(creationCode, constructorArgs);
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                deployer,
                salt,
                keccak256(bytecode)
            )
        );
        return address(uint160(uint256(hash)));
    }

    function _toBinary(uint160 value) internal pure returns (string memory) {
        bytes memory result = new bytes(14);
        for (uint256 i = 0; i < 14; i++) {
            result[13 - i] = (value & (1 << i)) != 0 ? bytes1("1") : bytes1("0");
        }
        return string(result);
    }

    function _outputDeploymentJson(
        address poolManager,
        address usdc,
        address priceFeed,
        address debtHook,
        address orderBook,
        address treasury
    ) internal view {
        console.log("\n=== Deployment JSON ===");
        console.log("{");
        console.log('  "chainId": 1301,');
        console.log('  "poolManager": "', poolManager, '",');
        console.log('  "usdc": "', usdc, '",');
        console.log('  "priceFeed": "', priceFeed, '",');
        console.log('  "debtHook": "', debtHook, '",');
        console.log('  "debtOrderBook": "', orderBook, '",');
        console.log('  "treasury": "', treasury, '"');
        console.log("}");
        
        console.log("\n=== Environment Variables for Frontend ===");
        console.log("NEXT_PUBLIC_POOL_MANAGER=", poolManager);
        console.log("NEXT_PUBLIC_USDC_ADDRESS=", usdc);
        console.log("NEXT_PUBLIC_PRICE_FEED=", priceFeed);
        console.log("NEXT_PUBLIC_DEBT_HOOK=", debtHook);
        console.log("NEXT_PUBLIC_DEBT_ORDER_BOOK=", orderBook);
        console.log("NEXT_PUBLIC_TREASURY=", treasury);
    }
}