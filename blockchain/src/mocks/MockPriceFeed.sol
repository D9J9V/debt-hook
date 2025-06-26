// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPriceFeed} from "../interfaces/IPriceFeed.sol";

/// @title MockPriceFeed
/// @notice Mock implementation of Chainlink price feed for testing
contract MockPriceFeed is IPriceFeed {
    int256 private _price;
    uint8 private _decimals;
    uint256 private _lastUpdate;
    uint80 private _roundId;
    string public description;

    constructor(int256 initialPrice, uint8 decimals_, string memory desc) {
        _price = initialPrice;
        _decimals = decimals_;
        description = desc;
        _lastUpdate = block.timestamp;
        _roundId = 1;
    }

    function setPrice(int256 newPrice) external {
        _price = newPrice;
        _lastUpdate = block.timestamp;
        _roundId++;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 price, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, _price, _lastUpdate, _lastUpdate, _roundId);
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function getRoundData(uint80 requestedRoundId)
        external
        view
        returns (uint80 roundId, int256 price, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        require(requestedRoundId <= _roundId, "Round not complete");
        // For simplicity, return the latest data
        return (requestedRoundId, _price, _lastUpdate, _lastUpdate, requestedRoundId);
    }
}
