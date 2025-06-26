// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";
import {DebtHookOptimized} from "../src/DebtHookOptimized.sol";

contract DeployHookMinimal is Script {
    // CREATE2 Deployer Proxy
    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);
    
    // Use existing deployed contracts from previous attempts
    address constant POOL_MANAGER = 0x1d933AB5bdE2b087a28e24A8E5d4DF77021CFEcC;
    address constant USDC = 0x73CFC55f831b5DD6E5Ee4CEF02E8c05be3F069F6;
    address constant PRICE_FEED = 0x3333Bc77EdF180D81ff911d439F02Db9e34e8603;
    address constant DEBT_ORDER_BOOK = 0xce060483D67b054cACE5c90001992085b46b4f66;
    
    address constant WETH = address(0);
    address constant OPERATOR = 0x2f131a86C5CB54685f0E940B920c54E152a44B02;
    
    uint24 constant POOL_FEE = 3000;
    int24 constant TICK_SPACING = 60;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Mining and Deploying DebtHook ===");
        console.log("Deployer:", deployer);
        console.log("Using existing contracts:");
        console.log("  PoolManager:", POOL_MANAGER);
        console.log("  USDC:", USDC);
        console.log("  PriceFeed:", PRICE_FEED);
        console.log("  OrderBook:", DEBT_ORDER_BOOK);

        vm.startBroadcast(deployerPrivateKey);

        // Define hook permissions - same as original
        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | 
            Hooks.AFTER_SWAP_FLAG | 
            Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );
        console.log("Required hook flags:", vm.toString(flags));
        console.log("Binary representation:", _toBinary(flags));

        // Prepare constructor args
        bytes memory constructorArgs = abi.encode(
            IPoolManager(POOL_MANAGER),
            PRICE_FEED,
            DEBT_ORDER_BOOK,
            deployer, // treasury
            Currency.wrap(WETH),
            Currency.wrap(USDC),
            POOL_FEE,
            TICK_SPACING
        );

        // Mine the hook address
        console.log("\nMining hook address with required permissions...");
        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            flags,
            type(DebtHookOptimized).creationCode,
            constructorArgs
        );
        
        console.log("Found hook address:", hookAddress);
        console.log("Salt:", vm.toString(salt));
        
        // Verify the address has correct permissions
        uint160 actualFlags = uint160(hookAddress) & Hooks.ALL_HOOK_MASK;
        console.log("Address permission bits:", _toBinary(actualFlags));
        require(actualFlags & flags == flags, "Mined address doesn't have required permissions");

        // Deploy DebtHook to the mined address
        DebtHookOptimized debtHook = new DebtHookOptimized{salt: salt}(
            IPoolManager(POOL_MANAGER),
            PRICE_FEED,
            DEBT_ORDER_BOOK,
            deployer,
            Currency.wrap(WETH),
            Currency.wrap(USDC),
            POOL_FEE,
            TICK_SPACING
        );
        
        require(address(debtHook) == hookAddress, "Hook deployed to wrong address!");
        console.log("\n[SUCCESS] DebtHook deployed to mined address:", address(debtHook));

        // Authorize the operator
        console.log("\nAuthorizing operator...");
        debtHook.authorizeOperator(OPERATOR, true);
        
        // Verify authorization
        bool isAuthorized = debtHook.authorizedOperators(OPERATOR);
        require(isAuthorized, "Operator authorization failed");
        console.log("[SUCCESS] Operator authorized:", OPERATOR);

        vm.stopBroadcast();

        // Output summary
        console.log("\n=== DEPLOYMENT COMPLETE ===");
        console.log("DebtHook:", address(debtHook));
        console.log("Operator:", OPERATOR);
        console.log("Treasury:", deployer);
        console.log("\nHook Address Analysis:");
        console.log("  Address:", hookAddress);
        console.log("  Permission bits:", _toBinary(actualFlags));
        console.log("  Has beforeSwap:", (actualFlags & Hooks.BEFORE_SWAP_FLAG) != 0);
        console.log("  Has afterSwap:", (actualFlags & Hooks.AFTER_SWAP_FLAG) != 0);
        console.log("  Has beforeSwapReturnsDelta:", (actualFlags & Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG) != 0);
        
        console.log("\n[NEXT STEPS]:");
        console.log("1. Update DebtOrderBook to use new DebtHook address");
        console.log("2. Update operator config with new addresses");
        console.log("3. Test batch loan creation");
    }
    
    function _toBinary(uint160 value) internal pure returns (string memory) {
        bytes memory result = new bytes(14);
        for (uint256 i = 0; i < 14; i++) {
            result[13 - i] = (value & (1 << i)) != 0 ? bytes1("1") : bytes1("0");
        }
        return string(result);
    }
}