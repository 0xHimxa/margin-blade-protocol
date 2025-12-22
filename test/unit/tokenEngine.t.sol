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
    event EdgeMinted(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, address indexed token, uint256 indexed amount);

    event EdgeBurned(address indexed user, uint256 amount);

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
        ERC20Mock(config.wethAddress).mint(USER, userStartBalne);
        ERC20Mock(config.wbtcAddress).mint(USER, userStartBalne);
    }

    modifier depositCollateral() {
        uint256 depositAmount = 1 ether;
        vm.prank(USER);
        ERC20Mock(config.wbtcAddress).approve(address(edgeEngine), depositAmount);
        vm.prank(USER);
        edgeEngine.depositCollateral(config.wbtcAddress, depositAmount);

        _;
    }
    modifier mintEdge() {
        vm.prank(USER);
        edgeEngine.mintEdge(45000e18);

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

        assertEq(wbtcCollateralPriceFeedAdd, config.wbtcPriceFeed);
    }

    function testEdgeAddress() external view {
        address edgeAddress = edgeEngine.getEdgeAddress();
        assertEq(edgeAddress, address(edge));
    }

    function testOraclePricePrecision() external view {
        uint256 oraclePricePrecision = edgeEngine.getOraclePricePrecision();
        uint256 tOraclePricePrecision = 1e10;
        assertEq(oraclePricePrecision, tOraclePricePrecision);
    }

    function testPrecision() external view {
        uint256 precision = edgeEngine.getPrecision();
        uint256 tPrecision = 1e18;
        assertEq(precision, tPrecision);
    }

    function testThreshold() external view {
        uint256 threshold = edgeEngine.getThreshold();
        uint256 tThreshold = 50;
        assertEq(threshold, tThreshold);
    }

    function testThresholdPrecision() external view {
        uint256 thresholdPrecision = edgeEngine.getThresholdPrecision();
        uint256 tThresholdPrecision = 100;
        assertEq(thresholdPrecision, tThresholdPrecision);
    }

    function testLiquidatorBonus() external view {
        uint256 liquidatorBonus = edgeEngine.getLiquidatorBonus();
        uint256 tLiquidatorBonus = 10;
        assertEq(liquidatorBonus, tLiquidatorBonus);
    }

    function testMinHealthFactor() external view {
        uint256 minHealthFactor = edgeEngine.getMinHealthFactor();
        uint256 tMinHealthFactor = 1e18;
        assertEq(minHealthFactor, tMinHealthFactor);
    }

    function testLiquidatorBonusPrecision() external view {
        uint256 liquidatorBonusPrecision = edgeEngine.getLiquidatorBonusPrecision();
        uint256 tLiquidatorBonusPrecision = 100;
        assertEq(liquidatorBonusPrecision, tLiquidatorBonusPrecision);
    }

    function testWethMinted() external view {
        uint256 userBalchek = ERC20Mock(config.wethAddress).balanceOf(USER);
        assertEq(userBalchek, 10 ether);
    }

    //Construnctor Test

    address[] public collateralAdd = [config.wbtcAddress, config.wethAddress];
    address[] public priceFeed = [config.wbtcPriceFeed];

    function testConstrutorReverCollateralAddAndPriceFeedLengthMismatch() external {
        vm.expectRevert(EdgeEngine.EdgeEngine__CollateralAddressAndPriceFeedLengthMismatch.selector);
        EdgeEngine engineTest = new EdgeEngine(collateralAdd, priceFeed, address(edge));
    }

    function testConstructorRevertEdgeAddressZero() external {
        priceFeed.push(config.wethPriceFeed);
        vm.expectRevert(EdgeEngine.EdgeEngine__EdgeContractCantbeAddressZero.selector);

        EdgeEngine engineTest = new EdgeEngine(collateralAdd, priceFeed, address(0));
    }

    // deposit function test

    function testDepositCollateralReverMinCantBeZero() external {
        vm.expectRevert(EdgeEngine.EdgeEngine__MustBeGreaterThanZero.selector);
        edgeEngine.depositCollateral(config.wbtcAddress, 0);
    }

    function testDepostCollateralReverAddressNotAllowed() external {
        vm.expectRevert(EdgeEngine.EdgeEngine__CollateralTokenNotAllowed.selector);

        edgeEngine.depositCollateral(address(90), 67);
    }

    //deposit sucesss

    function testDepositEmitCollateralDeposited() external {
        uint256 depositAmount = 1 ether;
        vm.startPrank(USER);
        ERC20Mock(config.wbtcAddress).approve(address(edgeEngine), depositAmount);
        vm.expectEmit(true, true, true, false);
        emit CollateralDeposited(USER, config.wbtcAddress, depositAmount);
        edgeEngine.depositCollateral(config.wbtcAddress, depositAmount);

        console.log(address(edgeEngine).balance, "engine balance");

        vm.stopPrank();
    }

    function testDepositCollateralSuccess() external depositCollateral {
        uint256 depositAmount = 1 ether;

        console.log(address(edgeEngine).balance, "engine balance");
        assertEq(ERC20Mock(config.wbtcAddress).balanceOf(address(edgeEngine)), depositAmount);
    }

    /// Minting test

    function testMintEdgeFailedAmountMutBeGreaterThanZero() external {
        vm.prank(USER);
        vm.expectRevert(EdgeEngine.EdgeEngine__MustBeGreaterThanZero.selector);
        edgeEngine.mintEdge(0);
    }

    function testMintingEdgeEngineRevertDepositCollateralFirst() external {
        vm.expectRevert(EdgeEngine.EdgeEngine__DepositCollateral_First.selector);
        vm.prank(USER);
        edgeEngine.mintEdge(100);
    }

    function testMintRevertMintinMoreThanCollateral() external depositCollateral {
        (uint256 collateralWorthOfEdge, uint256 totalMinted) =
            edgeEngine.getCollatralWorthOfEdgeAndEgdeMintedSoFar(USER);
        console.log(collateralWorthOfEdge, totalMinted, "here boy");

        vm.expectRevert(EdgeEngine.EdgeEngine__HealthFatorIsBroken__LiquidatingSoon.selector);

        vm.prank(USER);
        edgeEngine.mintEdge(collateralWorthOfEdge + 1);

        console.log(collateralWorthOfEdge, totalMinted, "here boy");
    }

    function testMintEdgrEmitEdgeMinted() external depositCollateral {
        vm.expectEmit(true, false, false, true);
        emit EdgeMinted(USER, 100);
        vm.prank(USER);
        edgeEngine.mintEdge(100);

        vm.stopPrank();
    }

    // burn Edge

    function testBurnEdgeFailedAmountMutBeGreaterThanZero() external depositCollateral mintEdge {
        vm.expectRevert(EdgeEngine.EdgeEngine__MustBeGreaterThanZero.selector);
        vm.prank(USER);
        edgeEngine.burnEdge(0);
    }

    function testBurnEdgeRevertDepositCollateralFirst() external {
        vm.expectRevert(EdgeEngine.EdgeEngine__DepositCollateral_First.selector);

        vm.prank(USER);
        edgeEngine.burnEdge(100);
    }

    function testBurnEdgeEmitEvent() external depositCollateral mintEdge {
        vm.prank(USER);
        edge.approve(address(edgeEngine), 100);

        vm.expectEmit(true, false, false, true);
        emit EdgeBurned(USER, 100);
        vm.prank(USER);
        edgeEngine.burnEdge(100);
    }

    // the code will not reach this line
    // else under flow

    // function testBurnRevertHealthFactorIsBroken() external depositCollateral mintEdge{
    //  vm.prank(USER);
    // edge.approve(address(edgeEngine), 45001e18);
    // vm.expectRevert(EdgeEngine.EdgeEngine__HealthFatorIsBroken__LiquidatingSoon.selector);

    //  vm.prank(USER);
    //     edgeEngine.burnEdge(45001e18);

    // }

    //withdraw collateral

    function testWithdrawCollateralRevertAmountMustBeGreaterThanZero() external depositCollateral {
        vm.expectRevert(EdgeEngine.EdgeEngine__MustBeGreaterThanZero.selector);
        vm.prank(USER);
        edgeEngine.withdrawCollateral(config.wbtcAddress, 0);
    }

    function testWithdrawCollateralRevertNoCollataralDeposited() external {
        vm.expectRevert(EdgeEngine.EdgeEngine__DepositCollateral_First.selector);
        vm.prank(USER);
        edgeEngine.withdrawCollateral(config.wbtcAddress, 1 ether);
    }

    function testWithdrawCollateralSuccess() external depositCollateral {
        uint256 withdrawAmount = 0.5 ether;
        vm.prank(USER);
        edgeEngine.withdrawCollateral(config.wbtcAddress, withdrawAmount);
        assertEq(ERC20Mock(config.wbtcAddress).balanceOf(USER), userStartBalne - 1 ether + withdrawAmount);
    }
    function testWithdrawCollateralRevertHealthFactorIsBroken() external depositCollateral mintEdge {
        vm.expectRevert(EdgeEngine.EdgeEngine__HealthFatorIsBroken__LiquidatingSoon.selector);
        vm.prank(USER);
        edgeEngine.withdrawCollateral(config.wbtcAddress, 0.6 ether);
    }



    function testWithdrawCollateralEmitEvent() external depositCollateral {
        uint256 withdrawAmount = 0.5 ether;
        vm.prank(USER);
        vm.expectEmit(true, true, true, false);
        emit CollateralWithdrawn(USER, config.wbtcAddress, withdrawAmount);
        edgeEngine.withdrawCollateral(config.wbtcAddress, withdrawAmount);}





     // get HealFator

     function testGetHealthFactor() external depositCollateral mintEdge {
        uint256 healthFactor = edgeEngine.getHealthFactor(USER);
        console.log(healthFactor, "health factor");
        assert(healthFactor >= edgeEngine.getMinHealthFactor());}   


// account information

function testGetAccountInformation() external depositCollateral mintEdge {  


    (uint256 collateralWorthInUSD, uint256 totalEdgeMinted) = edgeEngine.getAccountInformation(USER);
    console.log(totalEdgeMinted, "total edge minted");
    console.log(collateralWorthInUSD, "collateral worth in usd");
    assertEq(totalEdgeMinted, 45000e18);
   assert(collateralWorthInUSD >= 90000e18);
}


//ge Usd value of collateral

function testGetUsdValue() external depositCollateral {
    uint256 usdValue = edgeEngine.getUsdValue(config.wbtcAddress, 1 ether);
    console.log(usdValue, "usd value");
    assertEq(usdValue, 90000e18);

}


//get token amount from usd

function testGetTokenAmountFromUsd() external depositCollateral {
    uint256 tokenAmount = edgeEngine.getTokenValueFromUsd(config.wbtcAddress, 90000e18);
    console.log(tokenAmount, "token amount");
    assertEq(tokenAmount, 1 ether);}


    function testGetTokenAmountFromUsdRevertTokenNotAllowed() external depositCollateral {
        vm.expectRevert(EdgeEngine.EdgeEngine__CollateralTokenNotAllowed.selector);
        uint256 tokenAmount = edgeEngine.getTokenValueFromUsd(zeroAddress, 90000e18);}




        function testCollatralWorthOfEdgeAndEgdeMintedSoFar() external depositCollateral mintEdge {
            (uint256 collateralWorthOfEdge, uint256 totalMinted) = edgeEngine.getCollatralWorthOfEdgeAndEgdeMintedSoFar(USER);
            console.log(collateralWorthOfEdge, totalMinted, "here boy");
            assertEq(collateralWorthOfEdge, 45000e18);
            assertEq(totalMinted, 45000e18);
        }

    
    }
