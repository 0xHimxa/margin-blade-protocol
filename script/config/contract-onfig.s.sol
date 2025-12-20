// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Script} from "forge-std/Script.sol";
import {Wbtc} from "src/Token/Collateral-tokens/wbtc.sol";
import {Weth} from "src/Token/Collateral-tokens/weth.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {MockV3Aggregator} from "test/mocks/agg.sol";

contract InitailConfig is Script {
    error InitailConfig__ChainIdNotSupported();

    struct NetworkConfig {


        address wbtcPriceFeed;
        address wethPriceFeed;
        address wbtcAddress;
        address wethAddress;
    }

    int256 private constant ETH_PRICE = 3000e8;
    int256 private constant BTC_PRICE = 90000e8;
    uint8 private constant PRICE_DECIMALS = 8;

    function getConfig() external returns (NetworkConfig memory) {
        if (block.chainid == 31337) {
            return createAnvilNetworkConfig();
        } else if (block.chainid == 11155111) {
            return getSepoliaNetWorkConfig();
        } else {
            revert InitailConfig__ChainIdNotSupported();
        }
    }

    function getSepoliaNetWorkConfig() internal returns (NetworkConfig memory) {
        vm.startBroadcast();
        Wbtc wbtc = new Wbtc();
        Weth weth = new Weth();
        vm.stopBroadcast();

        return NetworkConfig({
            wbtcPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            wethPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wbtcAddress: address(wbtc),
            wethAddress: address(weth)
        });
    }

    function createAnvilNetworkConfig() internal returns (NetworkConfig memory localConfig) {
        vm.startBroadcast();
        ERC20Mock wbtc = new ERC20Mock();
        ERC20Mock weth = new ERC20Mock();
        MockV3Aggregator wbtcPriceFeed = new MockV3Aggregator(PRICE_DECIMALS, BTC_PRICE);
        MockV3Aggregator wethPriceFeed = new MockV3Aggregator(PRICE_DECIMALS, ETH_PRICE);
        vm.stopBroadcast();

        localConfig = NetworkConfig({
            wbtcPriceFeed: address(wbtcPriceFeed),
            wethPriceFeed: address(wethPriceFeed),
            wbtcAddress: address(wbtc),
            wethAddress: address(weth)
        });

        return localConfig;
    }
}
