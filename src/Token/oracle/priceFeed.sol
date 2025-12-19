// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title PriceFeed Library
 * @author Himxa
 * @notice Provides a wrapper for Chainlink Oracles with built-in safety checks.
 * @dev This library validates the price value and ensures the data is not stale
 * based on a 1-hour (3600s) heartbeat.
 */
library PriceFeed {
    ///////////////////
    // Errors
    ///////////////////
    error PriceFeed__InvalidOraclePrice();
    error PriceFeed__StalePrice();

    ///////////////////
    // Constants
    ///////////////////
    uint256 private constant HEARTBEAT_THRESHOLD = 3600; // 1 hour

    ///////////////////
    // Functions
    ///////////////////

    /**
     * @notice Fetches price data from Chainlink and performs safety checks.
     * @param _priceFeed The address of the AggregatorV3Interface contract.
     * @return roundId The round ID from Chainlink.
     * @return priceValue The current asset price.
     * @return startedAt Timestamp when the round started.
     * @return updatedAt Timestamp of the last update.
     * @return answeredInRound The round ID in which the answer was computed.
     * * @dev Reverts if the price is 0 or negative.
     * @dev Reverts if the update is older than the HEARTBEAT_THRESHOLD.
     */
    function getPriceFeedData(AggregatorV3Interface _priceFeed)
        internal
        view
        returns (uint80 roundId, int256 priceValue, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        (roundId, priceValue, startedAt, updatedAt, answeredInRound) = _priceFeed.latestRoundData();

        // 1. Check for valid price
        if (priceValue <= 0) {
            revert PriceFeed__InvalidOraclePrice();
        }

        // 2. Check for stale data (Heartbeat Check)
        // If the current time is more than 1 hour past the last update, the data is unreliable.
        uint256 secondsSinceUpdate = block.timestamp - updatedAt;
        if (secondsSinceUpdate > HEARTBEAT_THRESHOLD) {
            revert PriceFeed__StalePrice();
        }

        return (roundId, priceValue, startedAt, updatedAt, answeredInRound);
    }
}
