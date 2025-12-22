// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {EdgeEngine} from "src/Token/tokenEngine.sol";
import {Edge} from "src/Token/Edge-Token.sol";
import {DeployEngine} from "script/deployEngine.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {InitailConfig} from "script/config/contract-onfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract TestEdgeEngine is Test {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event EdgeMinted(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, address indexed token, uint256 indexed amount);
    event EdgeBurned(address indexed user, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    Edge edge;
    EdgeEngine edgeEngine;
    InitailConfig.NetworkConfig config;
    address public USER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public zeroAddress = address(0);
    uint256 public userStartBalne = 10 ether;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/
    function setUp() external {
        DeployEngine deployer = new DeployEngine();
        (edgeEngine, edge, config) = deployer.run();
        // vm.prank(USER);
        ERC20Mock(config.wethAddress).mint(USER, userStartBalne);
        ERC20Mock(config.wbtcAddress).mint(USER, userStartBalne);
    }

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
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

    /*//////////////////////////////////////////////////////////////
                          STATE VARIABLE TESTS
    //////////////////////////////////////////////////////////////*/
    
    // Checks if the engine returns the correct collateral addresses from the array
    function testGetCollateralAddress() external view {
        address wbtcCollateralAdd = edgeEngine.getCollarteralAddress(0);
        address wethCollateralAdd = edgeEngine.getCollarteralAddress(1);
        assertEq(wethCollateralAdd, config.wethAddress);
        assertEq(wbtcCollateralAdd, config.wbtcAddress);
    }

    // Verifies the mapping of collateral tokens to their respective price feeds
    function testGetCollateralPriceFeedAddress() external view {
        address wbtcCollateralPriceFeedAdd = edgeEngine.getCollateralTokenPriceFeedAddress(config.wbtcAddress);
        assertEq(wbtcCollateralPriceFeedAdd, config.wbtcPriceFeed);
    }

    // Ensures the engine is linked to the correct Edge token contract
    function testEdgeAddress() external view {
        address edgeAddress = edgeEngine.getEdgeAddress();
        assertEq(edgeAddress, address(edge));
    }

    // Checks the decimal precision used for oracle price data
    function testOraclePricePrecision() external view {
        uint256 oraclePricePrecision = edgeEngine.getOraclePricePrecision();
        uint256 tOraclePricePrecision = 1e10;
        assertEq(oraclePricePrecision, tOraclePricePrecision);
    }

    // Checks the standard precision used for calculations (1e18)
    function testPrecision() external view {
        uint256 precision = edgeEngine.getPrecision();
        uint256 tPrecision = 1e18;
        assertEq(precision, tPrecision);
    }

    // Verifies the liquidation threshold percentage
    function testThreshold() external view {
        uint256 threshold = edgeEngine.getThreshold();
        uint256 tThreshold = 50;
        assertEq(threshold, tThreshold);
    }

    // Verifies the denominator for threshold math
    function testThresholdPrecision() external view {
        uint256 thresholdPrecision = edgeEngine.getThresholdPrecision();
        uint256 tThresholdPrecision = 100;
        assertEq(thresholdPrecision, tThresholdPrecision);
    }

    // Verifies the bonus percentage given to liquidators
    function testLiquidatorBonus() external view {
        uint256 liquidatorBonus = edgeEngine.getLiquidatorBonus();
        uint256 tLiquidatorBonus = 10;
        assertEq(liquidatorBonus, tLiquidatorBonus);
    }

    // Ensures the minimum health factor is set to 1 (in 1e18 format)
    function testMinHealthFactor() external view {
        uint256 minHealthFactor = edgeEngine.getMinHealthFactor();
        uint256 tMinHealthFactor = 1e18;
        assertEq(minHealthFactor, tMinHealthFactor);
    }

    // Verifies the denominator for liquidator bonus math
    function testLiquidatorBonusPrecision() external view {
        uint256 liquidatorBonusPrecision = edgeEngine.getLiquidatorBonusPrecision();
        uint256 tLiquidatorBonusPrecision = 100;
        assertEq(liquidatorBonusPrecision, tLiquidatorBonusPrecision);
    }

    // Basic check to ensure the setUp mints the correct initial balance to the test user
    function testWethMinted() external view {
        uint256 userBalchek = ERC20Mock(config.wethAddress).balanceOf(USER);
        assertEq(userBalchek, 10 ether);
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/
    
    address[] public collateralAdd = [config.wbtcAddress, config.wethAddress];
    address[] public priceFeed = [config.wbtcPriceFeed];

    // Ensures constructor fails if collateral addresses and price feeds don't match in length
    function testConstrutorReverCollateralAddAndPriceFeedLengthMismatch() external {
        vm.expectRevert(EdgeEngine.EdgeEngine__CollateralAddressAndPriceFeedLengthMismatch.selector);
        EdgeEngine engineTest = new EdgeEngine(collateralAdd, priceFeed, address(edge));
    }

    // Ensures constructor fails if the Edge token address is zero
    function testConstructorRevertEdgeAddressZero() external {
        priceFeed.push(config.wethPriceFeed);
        vm.expectRevert(EdgeEngine.EdgeEngine__EdgeContractCantbeAddressZero.selector);

        EdgeEngine engineTest = new EdgeEngine(collateralAdd, priceFeed, address(0));
    }

    /*//////////////////////////////////////////////////////////////
                          DEPOSIT TESTS
    //////////////////////////////////////////////////////////////*/

    // Reverts if a user tries to deposit 0 amount
    function testDepositCollateralReverMinCantBeZero() external {
        vm.expectRevert(EdgeEngine.EdgeEngine__MustBeGreaterThanZero.selector);
        edgeEngine.depositCollateral(config.wbtcAddress, 0);
    }

    // Reverts if a user tries to deposit a token not supported by the protocol
    function testDepostCollateralReverAddressNotAllowed() external {
        vm.expectRevert(EdgeEngine.EdgeEngine__CollateralTokenNotAllowed.selector);
        edgeEngine.depositCollateral(address(90), 67);
    }

    // Checks that the proper event is emitted upon a successful deposit
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

    // Verifies that the engine actually receives the tokens after a deposit
    function testDepositCollateralSuccess() external depositCollateral {
        uint256 depositAmount = 1 ether;
        console.log(address(edgeEngine).balance, "engine balance");
        assertEq(ERC20Mock(config.wbtcAddress).balanceOf(address(edgeEngine)), depositAmount);
    }

    /*//////////////////////////////////////////////////////////////
                            MINTING TESTS
    //////////////////////////////////////////////////////////////*/

    // Reverts if minting amount is 0
    function testMintEdgeFailedAmountMutBeGreaterThanZero() external {
        vm.prank(USER);
        vm.expectRevert(EdgeEngine.EdgeEngine__MustBeGreaterThanZero.selector);
        edgeEngine.mintEdge(0);
    }

    // Reverts if a user tries to mint stablecoins without depositing collateral first
    function testMintingEdgeEngineRevertDepositCollateralFirst() external {
        vm.expectRevert(EdgeEngine.EdgeEngine__DepositCollateral_First.selector);
        vm.prank(USER);
        edgeEngine.mintEdge(100);
    }

    // Reverts if the user tries to mint more Edge than their collateral allows (HF check)
    function testMintRevertMintinMoreThanCollateral() external depositCollateral {
        (uint256 collateralWorthOfEdge, uint256 totalMinted) =
            edgeEngine.getCollatralWorthOfEdgeAndEgdeMintedSoFar(USER);
        console.log(collateralWorthOfEdge, totalMinted, "here boy");

        vm.expectRevert(EdgeEngine.EdgeEngine__HealthFatorIsBroken__LiquidatingSoon.selector);

        vm.prank(USER);
        edgeEngine.mintEdge(collateralWorthOfEdge + 1);

        console.log(collateralWorthOfEdge, totalMinted, "here boy");
    }

    // Verifies the EdgeMinted event fires correctly
    function testMintEdgrEmitEdgeMinted() external depositCollateral {
        vm.expectEmit(true, false, false, true);
        emit EdgeMinted(USER, 100);
        vm.prank(USER);
        edgeEngine.mintEdge(100);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            BURNING TESTS
    //////////////////////////////////////////////////////////////*/

    // Reverts if burning amount is 0
    function testBurnEdgeFailedAmountMutBeGreaterThanZero() external depositCollateral mintEdge {
        vm.expectRevert(EdgeEngine.EdgeEngine__MustBeGreaterThanZero.selector);
        vm.prank(USER);
        edgeEngine.burnEdge(0);
    }

    // Reverts if user tries to burn Edge without a position
    function testBurnEdgeRevertDepositCollateralFirst() external {
        vm.expectRevert(EdgeEngine.EdgeEngine__DepositCollateral_First.selector);

        vm.prank(USER);
        edgeEngine.burnEdge(100);
    }

    // Verifies the EdgeBurned event fires after approval and burn
    function testBurnEdgeEmitEvent() external depositCollateral mintEdge {
        vm.prank(USER);
        edge.approve(address(edgeEngine), 100);

        vm.expectEmit(true, false, false, true);
        emit EdgeBurned(USER, 100);
        vm.prank(USER);
        edgeEngine.burnEdge(100);
    }

    /*//////////////////////////////////////////////////////////////
                          WITHDRAWAL TESTS
    //////////////////////////////////////////////////////////////*/

    // Reverts if withdrawal amount is 0
    function testWithdrawCollateralRevertAmountMustBeGreaterThanZero() external depositCollateral {
        vm.expectRevert(EdgeEngine.EdgeEngine__MustBeGreaterThanZero.selector);
        vm.prank(USER);
        edgeEngine.withdrawCollateral(config.wbtcAddress, 0);
    }

    // Reverts if user tries to withdraw but hasn't deposited anything
    function testWithdrawCollateralRevertNoCollataralDeposited() external {
        vm.expectRevert(EdgeEngine.EdgeEngine__DepositCollateral_First.selector);
        vm.prank(USER);
        edgeEngine.withdrawCollateral(config.wbtcAddress, 1 ether);
    }

    // Verifies tokens are returned to user on success
    function testWithdrawCollateralSuccess() external depositCollateral {
        uint256 withdrawAmount = 0.5 ether;
        vm.prank(USER);
        edgeEngine.withdrawCollateral(config.wbtcAddress, withdrawAmount);
        assertEq(ERC20Mock(config.wbtcAddress).balanceOf(USER), userStartBalne - 1 ether + withdrawAmount);
    }

    // Prevents withdrawal if it would put the user below the liquidation threshold
    function testWithdrawCollateralRevertHealthFactorIsBroken() external depositCollateral mintEdge {
        vm.expectRevert(EdgeEngine.EdgeEngine__HealthFatorIsBroken__LiquidatingSoon.selector);
        vm.prank(USER);
        edgeEngine.withdrawCollateral(config.wbtcAddress, 0.6 ether);
    }

    // Verifies the CollateralWithdrawn event fires correctly
    function testWithdrawCollateralEmitEvent() external depositCollateral {
        uint256 withdrawAmount = 0.5 ether;
        vm.prank(USER);
        vm.expectEmit(true, true, true, false);
        emit CollateralWithdrawn(USER, config.wbtcAddress, withdrawAmount);
        edgeEngine.withdrawCollateral(config.wbtcAddress, withdrawAmount);
    }

    /*//////////////////////////////////////////////////////////////
                        GETTER & VIEW TESTS
    //////////////////////////////////////////////////////////////*/

    // Verifies health factor calculation is correct and above minimum for fresh mint
    function testGetHealthFactor() external depositCollateral mintEdge {
        uint256 healthFactor = edgeEngine.getHealthFactor(USER);
        console.log(healthFactor, "health factor");
        assert(healthFactor >= edgeEngine.getMinHealthFactor());
    }   

    // Verifies the summary of account collateral value and total debt
    function testGetAccountInformation() external depositCollateral mintEdge {  
        (uint256 collateralWorthInUSD, uint256 totalEdgeMinted) = edgeEngine.getAccountInformation(USER);
        console.log(totalEdgeMinted, "total edge minted");
        console.log(collateralWorthInUSD, "collateral worth in usd");
        assertEq(totalEdgeMinted, 45000e18);
        assert(collateralWorthInUSD >= 90000e18);
    }

    // Tests the conversion logic from token amount to USD value
    function testGetUsdValue() external depositCollateral {
        uint256 usdValue = edgeEngine.getUsdValue(config.wbtcAddress, 1 ether);
        console.log(usdValue, "usd value");
        assertEq(usdValue, 90000e18);
    }

    // Tests the inverse conversion: USD value to token amount
    function testGetTokenAmountFromUsd() external depositCollateral {
        uint256 tokenAmount = edgeEngine.getTokenValueFromUsd(config.wbtcAddress, 90000e18);
        console.log(tokenAmount, "token amount");
        assertEq(tokenAmount, 1 ether);
    }

    // Reverts conversion if the token address is invalid
    function testGetTokenAmountFromUsdRevertTokenNotAllowed() external depositCollateral {
        vm.expectRevert(EdgeEngine.EdgeEngine__CollateralTokenNotAllowed.selector);
        uint256 tokenAmount = edgeEngine.getTokenValueFromUsd(zeroAddress, 90000e18);
    }

    // Verifies internal logic for max edge that can be minted vs what is minted
    function testCollatralWorthOfEdgeAndEgdeMintedSoFar() external depositCollateral mintEdge {
        (uint256 collateralWorthOfEdge, uint256 totalMinted) = edgeEngine.getCollatralWorthOfEdgeAndEgdeMintedSoFar(USER);
        console.log(collateralWorthOfEdge, totalMinted, "here boy");
        assertEq(collateralWorthOfEdge, 45000e18);
        assertEq(totalMinted, 45000e18);
    }

    /*//////////////////////////////////////////////////////////////
                        MULTI-ACTION TESTS
    //////////////////////////////////////////////////////////////*/

    // Tests the convenience function for depositing and minting in one transaction
    function testDepositCollateralAndMintEdgeMultipleTimes() external {
        uint256 depositAmount = 1 ether;
        vm.prank(USER);
        ERC20Mock(config.wbtcAddress).approve(address(edgeEngine), depositAmount);
        vm.prank(USER);
        edgeEngine.depositCollateralAndMintEdge(config.wbtcAddress, depositAmount, 45000e18);

        (uint256 collateralWorthOfEdge, uint256 totalMinted) = edgeEngine.getCollatralWorthOfEdgeAndEgdeMintedSoFar(USER);
        assertEq(totalMinted, 45000e18);
        assertEq(collateralWorthOfEdge, 45000e18);
    }

    // Tests the convenience function for burning debt and withdrawing collateral in one transaction
    function testwithdrawCollateralAndBurnEdge() external depositCollateral mintEdge {
        uint256 withdrawAmount = 0.5 ether;
        uint256 edgeToBurn = 45000e18;
        uint256 useCollateral = edgeEngine.getCollateralBalance(USER, config.wbtcAddress);
        console.log(useCollateral, "user collateral before withdraw and burn");
   
        vm.prank(USER);
        edge.approve(address(edgeEngine), edgeToBurn);
        vm.prank(USER);
        edgeEngine.burnEdgeAndWithdrawCollateral(config.wbtcAddress, withdrawAmount, edgeToBurn);
     
        uint256 useCollateralAfter = edgeEngine.getCollateralBalance(USER, config.wbtcAddress);
        console.log(useCollateralAfter, "user collateral after withdraw and burn");
        assertEq(useCollateralAfter, withdrawAmount);
    }
}