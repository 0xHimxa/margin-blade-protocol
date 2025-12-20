// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {EdgeEngine} from "src/Token/tokenEngine.sol";
import {Edge} from "src/Token/Edge-Token.sol";
import {DeployEngine} from "script/deployEngine.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {InitailConfig} from "script/config/contract-onfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract TestEdgeEngine is Test {



    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);





    Edge edge;
    EdgeEngine edgeEngine;
    InitailConfig.NetworkConfig config;
    address public USER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public zeroAddress = address(0);
    uint256 public userStartBalne = 10 ether;

    function setUp() external {
        DeployEngine deployer = new DeployEngine();
        (edgeEngine, edge, config) = deployer.run();
        // vm.prank(USER);
         ERC20Mock(config.wethAddress).mint(USER,userStartBalne);
         ERC20Mock(config.wbtcAddress).mint(USER,userStartBalne);
    }




modifier depositCollateral(){
uint256 depositAmount = 1 ether;
vm.startPrank(USER);
ERC20Mock(config.wbtcAddress).approve(address(edgeEngine), depositAmount);
edgeEngine.depositCollateral(config.wbtcAddress, depositAmount);
vm.stopPrank();



_;

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

 function testConstructorRevertEdgeAddressZero() external{
    priceFeed.push(config.wethPriceFeed);
 vm.expectRevert(EdgeEngine.EdgeEngine__EdgeContractCantbeAddressZero.selector);


 EdgeEngine engineTest = new EdgeEngine(collateralAdd, priceFeed ,address(0));


 }


 // deposit function test

 function testDepositCollateralReverMinCantBeZero() external{
    vm.expectRevert(EdgeEngine.EdgeEngine__MustBeGreaterThanZero.selector);
    edgeEngine.depositCollateral(config.wbtcAddress, 0);
 }


function testDepostCollateralReverAddressNotAllowed() external{
    vm.expectRevert(EdgeEngine.EdgeEngine__CollateralTokenNotAllowed.selector);

    edgeEngine.depositCollateral(address(90),67);


   
}

//deposit sucesss





function testDepositEmitCollateralDeposited() external {
uint256 depositAmount = 1 ether;
vm.startPrank(USER);
ERC20Mock(config.wbtcAddress).approve(address(edgeEngine), depositAmount);
vm.expectEmit(true, true , true, false);
emit CollateralDeposited(USER, config.wbtcAddress, depositAmount);
edgeEngine.depositCollateral(config.wbtcAddress, depositAmount);

console.log(address(edgeEngine).balance,'engine balance');

vm.stopPrank();


}

// we be back to this soon

// function testDepositCollateralSuccess() external depositCollateral{
//     uint256 depositAmount = 1 ether;
    
//     console.log(address(edgeEngine).balance,'engine balance');
// //  assertEq(address(edgeEngine).balance, depositAmount);

   

// }




}
