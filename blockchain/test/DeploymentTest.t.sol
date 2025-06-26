// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {DebtHook} from "../src/DebtHook.sol";
import {DebtOrderBook} from "../src/DebtOrderBook.sol";
import {MockPriceFeed} from "../src/mocks/MockPriceFeed.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract DeploymentTest is Test {
    // Test constants
    address constant WETH = address(0);
    uint24 constant POOL_FEE = 3000;
    int24 constant TICK_SPACING = 60;
    
    address deployer = makeAddr("deployer");
    address treasury = makeAddr("treasury");

    function setUp() public {
        vm.deal(deployer, 100 ether);
    }

    function test_HookMining() public {
        // Test that we can mine a valid hook address
        uint160 targetFlags = uint160(
            Hooks.BEFORE_SWAP_FLAG | 
            Hooks.AFTER_SWAP_FLAG | 
            Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );

        // Create dummy constructor args
        bytes memory constructorArgs = abi.encode(
            address(0x1), // pool manager
            address(0x2), // price feed
            address(0x3), // order book
            treasury,
            Currency.wrap(WETH),
            Currency.wrap(address(0x4)), // USDC
            POOL_FEE,
            TICK_SPACING
        );

        // Mine address
        (address hookAddress, bytes32 salt) = HookMiner.find(
            deployer,
            targetFlags,
            type(DebtHook).creationCode,
            constructorArgs
        );

        // Verify the mined address has correct flags
        uint160 actualFlags = uint160(hookAddress) & Hooks.ALL_HOOK_MASK;
        assertEq(actualFlags, targetFlags, "Mined address has incorrect flags");
        
        console.log("Successfully mined hook address:", hookAddress);
        console.log("Salt:", vm.toString(salt));
    }

    function test_DeploymentWithMinedAddress() public {
        vm.startPrank(deployer);

        // Deploy infrastructure
        PoolManager poolManager = new PoolManager(deployer);
        MockERC20 usdc = new MockERC20("USD Coin", "USDC", 6);
        MockPriceFeed priceFeed = new MockPriceFeed(2000e8, 8, "ETH/USD");

        // Mine hook address with placeholder orderbook
        uint160 targetFlags = uint160(
            Hooks.BEFORE_SWAP_FLAG | 
            Hooks.AFTER_SWAP_FLAG | 
            Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );

        bytes memory hookConstructorArgs = abi.encode(
            poolManager,
            address(priceFeed),
            address(0x1234), // placeholder orderbook
            treasury,
            Currency.wrap(WETH),
            Currency.wrap(address(usdc)),
            POOL_FEE,
            TICK_SPACING
        );

        (address expectedHookAddress, bytes32 hookSalt) = HookMiner.find(
            deployer,
            targetFlags,
            type(DebtHook).creationCode,
            hookConstructorArgs
        );

        // Deploy hook to mined address
        DebtHook debtHook = new DebtHook{salt: hookSalt}(
            IPoolManager(address(poolManager)),
            address(priceFeed),
            address(0x1234), // placeholder orderbook
            treasury,
            Currency.wrap(WETH),
            Currency.wrap(address(usdc)),
            POOL_FEE,
            TICK_SPACING
        );

        // Verify deployment address
        assertEq(address(debtHook), expectedHookAddress, "Hook deployed to wrong address");

        // Deploy the actual orderbook
        DebtOrderBook orderBook = new DebtOrderBook(
            address(debtHook),
            address(usdc)
        );

        // Verify hook permissions
        uint160 actualFlags = uint160(address(debtHook)) & Hooks.ALL_HOOK_MASK;
        assertEq(actualFlags, targetFlags, "Hook has incorrect permissions");

        // Verify hook configuration
        assertEq(address(debtHook.priceFeed()), address(priceFeed));
        assertEq(debtHook.debtOrderBook(), address(0x1234)); // This would be the orderbook in production after redeployment
        assertEq(debtHook.treasury(), treasury);

        vm.stopPrank();
    }

    function test_HookPermissionBits() public {
        // Test individual permission bits
        uint160 beforeSwap = Hooks.BEFORE_SWAP_FLAG;
        uint160 afterSwap = Hooks.AFTER_SWAP_FLAG;
        uint160 beforeSwapReturnsDelta = Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG;

        assertEq(beforeSwap, 0x80, "BEFORE_SWAP_FLAG incorrect");
        assertEq(afterSwap, 0x40, "AFTER_SWAP_FLAG incorrect");
        assertEq(beforeSwapReturnsDelta, 0x08, "BEFORE_SWAP_RETURNS_DELTA_FLAG incorrect");

        // Test combined flags
        uint160 combinedFlags = beforeSwap | afterSwap | beforeSwapReturnsDelta;
        assertEq(combinedFlags, 0xC8, "Combined flags incorrect");

        // Test binary representation (last 14 bits)
        assertEq(combinedFlags & Hooks.ALL_HOOK_MASK, 0xC8, "Masked flags incorrect");
    }

    function test_Create2AddressPrediction() public {
        // Test that we can correctly predict CREATE2 addresses
        address deployer_ = address(this);
        bytes32 salt = bytes32(uint256(42));
        bytes memory creationCode = type(MockERC20).creationCode;
        bytes memory constructorArgs = abi.encode("Test", "TST", 18);

        // Predict address
        address predicted = computeCreate2Address(
            deployer_,
            salt,
            keccak256(abi.encodePacked(creationCode, constructorArgs))
        );

        // Deploy with CREATE2
        MockERC20 token = new MockERC20{salt: salt}("Test", "TST", 18);

        // Verify prediction
        assertEq(address(token), predicted, "CREATE2 address prediction failed");
    }

    // Helper function to compute CREATE2 address
    function computeCreate2Address(
        address deployer_,
        bytes32 salt,
        bytes32 bytecodeHash
    ) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            deployer_,
            salt,
            bytecodeHash
        )))));
    }
}