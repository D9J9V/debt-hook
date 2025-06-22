// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPriceFeed {
    /**
     * @notice Returns the latest price of ETH in USD
     * @return price The price with 8 decimals (Chainlink standard)
     */
    function latestAnswer() external view returns (int256 price);
    
    /**
     * @notice Returns the number of decimals in the price
     * @return decimals The number of decimals (typically 8 for USD feeds)
     */
    function decimals() external view returns (uint8);
}