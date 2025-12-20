// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {EdgeEngine} from "src/Token/tokenEngine.sol";
import {Edge} from "src/Token/Edge-Token.sol";
import {DeployEngine} from "script/deployEngine.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {InitailConfig} from "script/config/contract-onfig.s.sol";

contract TestEdgeEngine is Test {
    Edge edge;
    EdgeEngine edgeEngine;
    InitailConfig.NetworkConfig config;
    address public USER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function setUp() external {
        DeployEngine deployer = new DeployEngine();
        (edgeEngine, edge, config) = deployer.run();
        // vm.prank(USER);
        // edge.mint(USER, 10 ether);
    }

   
}
