// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {Script, console} from "forge-std/Script.sol";
import {EdgeEngine} from "src/Token/tokenEngine.sol";
import {Edge} from "src/Token/Edge-Token.sol";
import {InitailConfig} from "script/config/contract-onfig.s.sol";

contract DeployEngine is Script {
    address[] public priceFeed;
    address[] public collateralToken;
    address public owner = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function run() external returns (EdgeEngine, Edge, InitailConfig.NetworkConfig memory) {
        InitailConfig initialConfig = new InitailConfig();
        InitailConfig.NetworkConfig memory config = initialConfig.getConfig();
        vm.startBroadcast();
        Edge edge = new Edge("EDGE", "EDGE");
        priceFeed = [config.wbtcPriceFeed, config.wethPriceFeed];
        collateralToken = [config.wbtcAddress, config.wethAddress];
        EdgeEngine edgeEngine = new EdgeEngine(collateralToken, priceFeed, address(edge));
        edge.transferOwnership(address(edgeEngine));

        vm.stopBroadcast();

        return (edgeEngine, edge, config);
    }
}
