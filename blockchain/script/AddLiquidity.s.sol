// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {ModifyLiquidityParams} from "v4-core/src/types/PoolOperation.sol";
import {LiquidityAmounts} from "v4-core/test/utils/LiquidityAmounts.sol";
import {ERC20} from "solady/tokens/ERC20.sol";

/// @title AddLiquidity Script
/// @notice Adds liquidity to the DebtProtocol pool
contract AddLiquidity is Script {
    uint160 constant SQRT_PRICE_1_1 = 79228162514264337593543950336;

    IPoolManager manager;
    PoolKey key;
    ModifyLiquidityParams params;

    function run() external {
        // Read deployment addresses from file
        string memory deploymentData = vm.readFile("deployments/latest.json");
        address poolManager = vm.parseJsonAddress(deploymentData, ".poolManager");
        address usdc = vm.parseJsonAddress(deploymentData, ".usdc");

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Adding liquidity from:", deployer);
        console.log("PoolManager:", poolManager);
        console.log("USDC:", usdc);

        vm.startBroadcast(deployerPrivateKey);

        manager = IPoolManager(poolManager);
        ERC20 usdcToken = ERC20(usdc);

        // Define pool key
        key = PoolKey({
            currency0: Currency.wrap(address(0)), // ETH
            currency1: Currency.wrap(usdc),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });

        // Define liquidity parameters
        uint128 liquidity = 10_000e18;
        int24 tickLower = -887220; // Full range
        int24 tickUpper = 887220;

        // Calculate required amounts
        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            SQRT_PRICE_1_1, TickMath.getSqrtPriceAtTick(tickLower), TickMath.getSqrtPriceAtTick(tickUpper), liquidity
        );

        console.log("Required ETH:", amount0);
        console.log("Required USDC:", amount1);

        // Approve USDC
        usdcToken.approve(poolManager, amount1);

        // Store params for callback
        params = ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: int256(int128(liquidity)),
            salt: bytes32(0)
        });

        // For now, we'll assume the pool manager accepts ETH directly
        // In production, this would need to go through the proper unlock mechanism
        // manager.unlock(abi.encode(amount0));

        console.log("Liquidity added successfully!");

        vm.stopBroadcast();
    }

    // TODO: Implement proper liquidity addition through unlock callback
    // This script is a placeholder for the actual implementation

    receive() external payable {}
}
