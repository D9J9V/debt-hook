// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

/// @title Verify Script
/// @notice Verifies deployed contracts on Etherscan
contract Verify is Script {
    function run() external view {
        // Read deployment addresses
        string memory deploymentData = vm.readFile("deployments/latest.json");
        address poolManager = vm.parseJsonAddress(deploymentData, ".poolManager");
        address usdc = vm.parseJsonAddress(deploymentData, ".usdc");
        address priceFeed = vm.parseJsonAddress(deploymentData, ".priceFeed");
        address debtProtocol = vm.parseJsonAddress(deploymentData, ".debtProtocol");
        address debtOrderBook = vm.parseJsonAddress(deploymentData, ".debtOrderBook");
        address treasury = vm.parseJsonAddress(deploymentData, ".treasury");

        console.log("Verifying contracts...");

        // Generate verification commands
        console.log("\nRun these commands to verify contracts:");

        // MockERC20 (USDC)
        console.log("\n# Verify USDC:");
        console.log(
            string(
                abi.encodePacked(
                    "forge verify-contract ",
                    vm.toString(usdc),
                    " MockERC20 --constructor-args ",
                    vm.toString(abi.encode("USD Coin", "USDC", uint8(6)))
                )
            )
        );

        // MockPriceFeed
        console.log("\n# Verify PriceFeed:");
        console.log(
            string(
                abi.encodePacked(
                    "forge verify-contract ",
                    vm.toString(priceFeed),
                    " MockPriceFeed --constructor-args ",
                    vm.toString(abi.encode(int256(2000e8), uint8(8), "ETH/USD"))
                )
            )
        );

        // DebtProtocol
        console.log("\n# Verify DebtProtocol:");
        console.log(
            string(
                abi.encodePacked(
                    "forge verify-contract ",
                    vm.toString(debtProtocol),
                    " DebtProtocol --constructor-args ",
                    vm.toString(
                        abi.encode(
                            poolManager,
                            address(0), // ETH
                            usdc,
                            uint24(3000),
                            int24(60),
                            priceFeed,
                            treasury,
                            debtOrderBook
                        )
                    )
                )
            )
        );

        // DebtOrderBook
        console.log("\n# Verify DebtOrderBook:");
        console.log(
            string(
                abi.encodePacked(
                    "forge verify-contract ",
                    vm.toString(debtOrderBook),
                    " DebtOrderBook --constructor-args ",
                    vm.toString(abi.encode(debtProtocol, usdc))
                )
            )
        );

        console.log("\nAdd --etherscan-api-key and --rpc-url to each command");
    }
}
