// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";

/// @title Test Hook Mining Script
/// @notice Tests the HookMiner functionality to ensure we can find valid addresses
contract TestHookMining is Script {
    function run() external view {
        console.log("=== Testing Hook Mining ===");
        
        // Test different flag combinations
        _testFlags("BEFORE_SWAP only", Hooks.BEFORE_SWAP_FLAG);
        _testFlags("AFTER_SWAP only", Hooks.AFTER_SWAP_FLAG);
        _testFlags("BEFORE_SWAP + AFTER_SWAP", Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG);
        _testFlags(
            "BEFORE_SWAP + AFTER_SWAP + BEFORE_SWAP_RETURNS_DELTA",
            Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );
        
        // Test our specific flags
        uint160 debtHookFlags = uint160(
            Hooks.BEFORE_SWAP_FLAG | 
            Hooks.AFTER_SWAP_FLAG | 
            Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );
        
        console.log("\n=== DebtHook Flags Test ===");
        console.log("Required flags (hex):", vm.toString(debtHookFlags));
        console.log("Required flags (binary):", _toBinary(debtHookFlags));
        
        // Simulate finding an address
        bytes memory dummyCode = hex"6080604052348015600f57600080fd5b50603f80601d6000396000f3fe6080604052600080fdfea2646970667358221220";
        bytes memory dummyArgs = abi.encode(address(0x1234));
        
        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this),
            debtHookFlags,
            dummyCode,
            dummyArgs
        );
        
        console.log("Found valid address:", hookAddress);
        console.log("Salt:", vm.toString(salt));
        
        uint160 actualFlags = uint160(hookAddress) & Hooks.ALL_HOOK_MASK;
        console.log("Actual flags (hex):", vm.toString(actualFlags));
        console.log("Actual flags (binary):", _toBinary(actualFlags));
        console.log("Flags match:", actualFlags == debtHookFlags);
    }
    
    function _testFlags(string memory description, uint160 flags) internal view {
        console.log("\nTesting:", description);
        console.log("Flags (hex):", vm.toString(flags));
        console.log("Flags (binary):", _toBinary(flags));
        
        // Show which hook functions are enabled
        if (flags & Hooks.BEFORE_INITIALIZE_FLAG != 0) console.log("  - beforeInitialize: true");
        if (flags & Hooks.AFTER_INITIALIZE_FLAG != 0) console.log("  - afterInitialize: true");
        if (flags & Hooks.BEFORE_ADD_LIQUIDITY_FLAG != 0) console.log("  - beforeAddLiquidity: true");
        if (flags & Hooks.AFTER_ADD_LIQUIDITY_FLAG != 0) console.log("  - afterAddLiquidity: true");
        if (flags & Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG != 0) console.log("  - beforeRemoveLiquidity: true");
        if (flags & Hooks.AFTER_REMOVE_LIQUIDITY_FLAG != 0) console.log("  - afterRemoveLiquidity: true");
        if (flags & Hooks.BEFORE_SWAP_FLAG != 0) console.log("  - beforeSwap: true");
        if (flags & Hooks.AFTER_SWAP_FLAG != 0) console.log("  - afterSwap: true");
        if (flags & Hooks.BEFORE_DONATE_FLAG != 0) console.log("  - beforeDonate: true");
        if (flags & Hooks.AFTER_DONATE_FLAG != 0) console.log("  - afterDonate: true");
        if (flags & Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG != 0) console.log("  - beforeSwapReturnsDelta: true");
        if (flags & Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG != 0) console.log("  - afterSwapReturnsDelta: true");
        if (flags & Hooks.AFTER_ADD_LIQUIDITY_RETURNS_DELTA_FLAG != 0) console.log("  - afterAddLiquidityReturnsDelta: true");
        if (flags & Hooks.AFTER_REMOVE_LIQUIDITY_RETURNS_DELTA_FLAG != 0) console.log("  - afterRemoveLiquidityReturnsDelta: true");
    }
    
    function _toBinary(uint160 value) internal pure returns (string memory) {
        bytes memory result = new bytes(14);
        for (uint256 i = 0; i < 14; i++) {
            result[13 - i] = (value & (1 << i)) != 0 ? bytes1("1") : bytes1("0");
        }
        return string(result);
    }
}