// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {EdgeEngine} from "src/Token/tokenEngine.sol";
import {Edge} from "src/Token/Edge-Token.sol";
import {DeployEngine} from "script/deployEngine.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {InitailConfig} from "script/config/contract-onfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract TestEdgeEngine is Test {



error EdgeEngine__CollateralAddressAndPriceFeedLengthMismatch();




    Edge edge;
    EdgeEngine edgeEngine;
    InitailConfig.NetworkConfig config;
    address public USER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function setUp() external {
        DeployEngine deployer = new DeployEngine();
        (edgeEngine, edge, config) = deployer.run();
        // vm.prank(USER);
         ERC20Mock(config.wethAddress).mint(USER, 10 ether);
    }



    // state varrable tesst


function testGetCollateralAddress() external view {
    address wbtcCollateralAdd = edgeEngine.getCollarteralAddress(0);
address wethCollateralAdd = edgeEngine.getCollarteralAddress(1);
assertEq(wethCollateralAdd, config.wethAddress);
    assertEq(wbtcCollateralAdd, config.wbtcAddress);

}

function testGetCollateralPriceFeedAddress() external view {
    address wbtcCollateralPriceFeedAdd = edgeEngine.getCollateralTokenPriceFeedAddress(config.wbtcAddress);  
    
    assertEq(wbtcCollateralPriceFeedAdd , config.wbtcPriceFeed);
    
    }

function testEdgeAddress() external view{
    address edgeAddress = edgeEngine.getEdgeAddress();
    assertEq(edgeAddress, address(edge));
}


 function testOraclePricePrecision() external view{
    uint256 oraclePricePrecision = edgeEngine.getOraclePricePrecision();
    uint256 tOraclePricePrecision = 1e10;
    assertEq(oraclePricePrecision, tOraclePricePrecision);
}

function testPrecision() external view{
    uint256 precision = edgeEngine.getPrecision();
    uint256 tPrecision = 1e18;
    assertEq(precision, tPrecision);
}

function testThreshold() external view{
    uint256 threshold = edgeEngine.getThreshold();
    uint256 tThreshold = 50;
    assertEq(threshold, tThreshold);
}

function testThresholdPrecision() external view{
    uint256 thresholdPrecision = edgeEngine.getThresholdPrecision();
    uint256 tThresholdPrecision = 100;
    assertEq(thresholdPrecision, tThresholdPrecision);
}

function testLiquidatorBonus() external view{
    uint256 liquidatorBonus = edgeEngine.getLiquidatorBonus();
    uint256 tLiquidatorBonus = 10;
    assertEq(liquidatorBonus, tLiquidatorBonus);
}




function testMinHealthFactor() external view{
    uint256 minHealthFactor = edgeEngine.getMinHealthFactor();
    uint256 tMinHealthFactor = 1e18;
    assertEq(minHealthFactor, tMinHealthFactor);
}

function testLiquidatorBonusPrecision() external view{
    uint256 liquidatorBonusPrecision = edgeEngine.getLiquidatorBonusPrecision();
    uint256 tLiquidatorBonusPrecision = 100;
    assertEq(liquidatorBonusPrecision, tLiquidatorBonusPrecision);
}





function testWethMinted() external view{
    uint256 userBalchek = ERC20Mock(config.wethAddress).balanceOf(USER);
    assertEq(userBalchek, 10 ether);
}


//Construnctor Test


address[] public collateralAdd = [config.wbtcAddress, config.wethAddress];
address[] public priceFeed = [config.wbtcPriceFeed];

 function testConstrutorReverCollateralAddAndPriceFeedLengthMismatch() external {
 
 vm.expectRevert(EdgeEngine.EdgeEngine__CollateralAddressAndPriceFeedLengthMismatch.selector);
 EdgeEngine engineTest = new EdgeEngine(collateralAdd, priceFeed ,address(edge));
 
 
 
 
 }



   
}
