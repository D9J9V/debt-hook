// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";
import {DebtHook} from "../src/DebtHook.sol";

/// @title Update DebtHook Script
/// @notice Updates the DebtHook contract with operator authorization
contract UpdateDebtHook is Script {
    // CREATE2 Deployer Proxy - available on most chains
    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);
    
    // Existing Unichain Sepolia deployment addresses
    address constant POOL_MANAGER = 0x5b73C5498c1E3b4dbA84de0F1833c4a029d90519;
    address constant DEBT_ORDER_BOOK = 0xDB8cFf278adCCF9E9b5da745B44E754fC4EE3C76;
    address constant CHAINLINK_PRICE_FEED = 0x34A1D3fff3958843C43aD80F30b94c510645C316;
    address constant USDC = 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496;
    address constant EXPECTED_HOOK_ADDRESS = 0x0C075a62FD69EA6Db1F65566911C4f1D221e40c8;
    
    // ETH is native token
    address constant WETH = address(0);
    
    // Pool configuration
    uint24 constant POOL_FEE = 3000; // 0.3%
    int24 constant TICK_SPACING = 60;
    
    // Operator address from deployment
    address constant OPERATOR_ADDRESS = 0x2f131a86C5CB54685f0E940B920c54E152a44B02;

    function run() external {
        uint256 deployerPrivateKey = vm.envOr("PRIVATE_KEY", uint256(0));
        address deployer;
        if (deployerPrivateKey == 0) {
            deployer = msg.sender;
        } else {
            deployer = vm.addr(deployerPrivateKey);
        }
        address treasury = vm.envOr("TREASURY", deployer);

        console.log("=== DebtHook Update ===");
        console.log("Deployer:", deployer);
        console.log("Treasury:", treasury);
        console.log("Expected Hook Address:", EXPECTED_HOOK_ADDRESS);
        console.log("Operator to authorize:", OPERATOR_ADDRESS);

        if (deployerPrivateKey == 0) {
            vm.startBroadcast();
        } else {
            vm.startBroadcast(deployerPrivateKey);
        }

        // Define hook permissions
        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | 
            Hooks.AFTER_SWAP_FLAG | 
            Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );
        console.log("Hook flags:", vm.toString(flags));

        // Prepare constructor arguments
        bytes memory constructorArgs = abi.encode(
            IPoolManager(POOL_MANAGER),
            CHAINLINK_PRICE_FEED,
            DEBT_ORDER_BOOK,
            treasury,
            Currency.wrap(WETH),
            Currency.wrap(USDC),
            POOL_FEE,
            TICK_SPACING
        );

        // Mine the salt for the existing hook address
        console.log("Mining salt for existing hook address...");
        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            flags,
            type(DebtHook).creationCode,
            constructorArgs
        );
        
        console.log("Found hook address:", hookAddress);
        console.log("Salt:", vm.toString(salt));
        
        // Verify it matches our expected address
        require(hookAddress == EXPECTED_HOOK_ADDRESS, "Hook address mismatch! The contract bytecode may have changed.");

        // Deploy updated DebtHook to the same address
        DebtHook debtHook = new DebtHook{salt: salt}(
            IPoolManager(POOL_MANAGER),
            CHAINLINK_PRICE_FEED,
            DEBT_ORDER_BOOK,
            treasury,
            Currency.wrap(WETH),
            Currency.wrap(USDC),
            POOL_FEE,
            TICK_SPACING
        );
        
        require(address(debtHook) == EXPECTED_HOOK_ADDRESS, "Hook deployed to wrong address!");
        console.log("DebtHook updated at:", address(debtHook));

        // Authorize the operator
        console.log("Authorizing operator...");
        debtHook.authorizeOperator(OPERATOR_ADDRESS, true);
        console.log("Operator authorized:", OPERATOR_ADDRESS);

        // Verify authorization
        bool isAuthorized = debtHook.authorizedOperators(OPERATOR_ADDRESS);
        console.log("Authorization verified:", isAuthorized);

        vm.stopBroadcast();

        // Output summary
        console.log("\n=== Update Summary ===");
        console.log("DebtHook updated at:", address(debtHook));
        console.log("Operator authorized:", OPERATOR_ADDRESS);
        console.log("Treasury:", treasury);
        console.log("Ready for batch loan creation!");
    }
}