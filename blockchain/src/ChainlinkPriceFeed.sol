// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IPriceFeed} from "./interfaces/IPriceFeed.sol";

/**
 * @title ChainlinkPriceFeed
 * @notice Wrapper for Chainlink price feeds to implement IPriceFeed interface
 * @dev This contract wraps Chainlink's AggregatorV3Interface to provide price data
 */
contract ChainlinkPriceFeed is IPriceFeed {
    AggregatorV3Interface public immutable aggregator;
    
    // Stale price check parameters
    uint256 public constant PRICE_STALENESS_THRESHOLD = 3600; // 1 hour
    
    error StalePrice();
    error InvalidPrice();
    
    /**
     * @notice Constructor
     * @param _aggregator The Chainlink aggregator contract address
     */
    constructor(address _aggregator) {
        require(_aggregator != address(0), "Invalid aggregator address");
        aggregator = AggregatorV3Interface(_aggregator);
    }
    
    /**
     * @notice Returns the latest round data from Chainlink
     * @return roundId The round ID
     * @return price The price (with decimals as specified by the feed)
     * @return startedAt Timestamp of when the round started
     * @return updatedAt Timestamp of when the round was updated
     * @return answeredInRound The round ID of the round in which the answer was computed
     */
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 price,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        (roundId, price, startedAt, updatedAt, answeredInRound) = aggregator.latestRoundData();
        
        // Validate the price data
        if (price <= 0) revert InvalidPrice();
        if (block.timestamp - updatedAt > PRICE_STALENESS_THRESHOLD) revert StalePrice();
        
        return (roundId, price, startedAt, updatedAt, answeredInRound);
    }
    
    /**
     * @notice Returns the number of decimals in the price
     * @return decimals The number of decimals (typically 8 for USD feeds)
     */
    function decimals() external view returns (uint8) {
        return aggregator.decimals();
    }
    
    /**
     * @notice Get the description of the price feed
     * @return description The description string (e.g., "ETH / USD")
     */
    function description() external view returns (string memory) {
        return aggregator.description();
    }
}