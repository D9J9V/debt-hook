// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {ChainlinkPriceFeed} from "../src/ChainlinkPriceFeed.sol";
import {IPriceFeed} from "../src/interfaces/IPriceFeed.sol";

contract ChainlinkIntegrationTest is Test {
    // Unichain Sepolia Chainlink ETH/USD price feed
    address constant CHAINLINK_ETH_USD = 0xd9c93081210dFc33326B2af4C2c11848095E6a9a;

    ChainlinkPriceFeed priceFeed;

    function setUp() public {
        // Fork Unichain Sepolia
        vm.createSelectFork("https://unichain-sepolia-rpc.publicnode.com");

        // Deploy wrapper
        priceFeed = new ChainlinkPriceFeed(CHAINLINK_ETH_USD);
    }

    function test_ChainlinkPriceFeed() public {
        // Get latest price data
        (uint80 roundId, int256 price, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            priceFeed.latestRoundData();

        console.log("Chainlink ETH/USD Price Feed Test");
        console.log("==================================");
        console.log("Round ID:", roundId);
        console.log("Price:", uint256(price));
        console.log("Updated at:", updatedAt);
        console.log("Current time:", block.timestamp);
        console.log("Time since update:", block.timestamp - updatedAt);

        // Verify price is reasonable (between $100 and $100,000)
        assertGt(price, 100e8, "Price too low");
        assertLt(price, 100000e8, "Price too high");

        // Check decimals
        uint8 decimals = priceFeed.decimals();
        console.log("Decimals:", decimals);
        assertEq(decimals, 8, "Expected 8 decimals for USD price feed");

        // Check description
        string memory description = priceFeed.description();
        console.log("Description:", description);
    }

    function test_RevertOnStalePrice() public {
        // Move time forward to make price stale
        vm.warp(block.timestamp + 3601); // 1 hour + 1 second

        // Should revert with StalePrice
        vm.expectRevert(ChainlinkPriceFeed.StalePrice.selector);
        priceFeed.latestRoundData();
    }
}
