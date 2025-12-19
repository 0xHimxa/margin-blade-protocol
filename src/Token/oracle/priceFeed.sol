// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

library PriceFeed {
    error PriceFeed__Oracle_Price_IsInvalid();
    error PriceFeed__PriceAt_Stale();

    function getPriceFeedData(AggregatorV3Interface _priceFeed)
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        (uint80 roundId, int256 priceValue, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            _priceFeed.latestRoundData();

        if (priceValue <= 0) revert PriceFeed__Oracle_Price_IsInvalid();

        if (block.timestamp - updatedAt > 3600) revert PriceFeed__PriceAt_Stale();

        return (roundId, priceValue, startedAt, updatedAt, answeredInRound);
    }
}
