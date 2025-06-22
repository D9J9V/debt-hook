// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPriceFeed {
    /**
     * @notice Returns the latest round data
     * @return roundId The round ID
     * @return price The price
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
    );
    
    /**
     * @notice Returns the number of decimals in the price
     * @return decimals The number of decimals (typically 8 for USD feeds)
     */
    function decimals() external view returns (uint8);
}