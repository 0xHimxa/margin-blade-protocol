// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Edge} from "./Edge-Token.sol";
import {EdgeEngineErrors} from "./abstrat-contracts/abstractEdgengine.sol";
import {PriceFeed} from "./oracle/priceFeed.sol";

/**
 * @title EdgeEngine
 * @author Himxa
 * @notice This contract manages the collateralization, minting, and liquidation of Edge tokens.
 * @dev Implements a decentralized stablecoin-like engine using Chainlink price feeds.
 */
contract EdgeEngine {
    using PriceFeed for AggregatorV3Interface;

    ///////////////////
    // Errors
    ///////////////////
    error EdgeEngine__MustBeGreaterThanZero();
    error EdgeEngine__CollateralTokenNotAllowed();
    error EdgeEngine__FailedToDepositCollateral();
    error EdgeEngine__CollateralAddressAndPriceFeedLengthMismatch();
    error EdgeEngine__WithdrawBalanceIsZero();
    error EdgeEngine__FaildToTransferCollateral();
    error EdgeEngine__HealthFatorIsBroken__LiquidatingSoon();
    error EdgeEngine__EdgeContractCantbeAddressZero();
    error EdgeEngine__FailedTo_MintEDGE();
    error EdgeEngine__EDGEbalceCantBeZero();
    error EdgeEngine__FailedTo_BurnEDGE();
    error EdgeEngine__FailedTo_TarnsferEDGEToBeBurn();
    error EdgeEngine__WithdrawExeedBalance();
    error EdgeEngine__UserHealthFactorIsOk();
    error EdgeEngine__HealthFactorNotImproved();
    error EdgeEngine__Oracle_Price_IsInvalid();
    error EdgeEngine__PriceAt_Stale();
    error EdgeEngine__DepositCollateral_First();
    error EdgeEngine__MintingMoreThanCollateralAllowed();

    ///////////////////
    // State Variables
    ///////////////////

    mapping(address collateralToken => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address collateralToken => uint256 amount)) private s_collateralDeposits;
    mapping(address user => uint256 mintedAmount) private s_mintedEdge;

    address[] private s_collateralTokens;
    Edge private immutable i_edge;

    // Constants for Math & Precision
    uint256 private constant ORACLE_PRICE_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant THRESHOLD = 50; // 50% Liquidation Threshold
    uint256 private constant THRESHOLD_PRECISION = 100;
    uint256 private constant LIQUIDATOR_BONUS = 10; // 10% Bonus
    uint256 private constant LIQUIDATOR_BONUS_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;

    ///////////////////
    // Events
    ///////////////////

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralWithdrawn(address indexed user, address indexed token, uint256 indexed amount);
    event EdgeMinted(address indexed user, uint256 amount);
    event EdgeBurned(address indexed user, uint256 amount);

    ///////////////////
    // Modifiers
    ///////////////////

    modifier amountGreaterThanZero(uint256 _amount) {
        if (_amount == 0) revert EdgeEngine__MustBeGreaterThanZero();
        _;
    }

    modifier isAllowedCollateral(address _token) {
        if (s_priceFeeds[_token] == address(0)) revert EdgeEngine__CollateralTokenNotAllowed();
        _;
    }

    modifier noCollatatralDeposited(address _user) {
        (uint256 collateralValue,) = getAccountInformation(_user);

        if (collateralValue == 0) {
            revert EdgeEngine__DepositCollateral_First();
        }

        _;
    }

    ///////////////////
    // Functions
    ///////////////////

    constructor(address[] memory _collateralTokens, address[] memory _priceFeeds, address _edgeAddress) {
        if (_collateralTokens.length != _priceFeeds.length) {
            revert EdgeEngine__CollateralAddressAndPriceFeedLengthMismatch();
        }
        if (_edgeAddress == address(0)) {
            revert EdgeEngine__EdgeContractCantbeAddressZero();
        }

        i_edge = Edge(_edgeAddress);

        for (uint256 i = 0; i < _collateralTokens.length; i++) {
            s_priceFeeds[_collateralTokens[i]] = _priceFeeds[i];
            s_collateralTokens.push(_collateralTokens[i]);
        }
    }

    ///////////////////
    // External Functions
    ///////////////////

    /**
     * @notice Convenience function to deposit collateral and mint Edge in one transaction.
     */
    function depositCollateralAndMintEdge(
        address _collateralAddress,
        uint256 _amountCollateral,
        uint256 _edgeAmountToMint
    ) external {
        depositCollateral(_collateralAddress, _amountCollateral);
        mintEdge(_edgeAmountToMint);
    }

    /**
     * @notice Convenience function to burn Edge and withdraw collateral in one transaction.
     */
    function burnEdgeAndWithdrawCollateral(
        address _collateralAddress,
        uint256 _amountCollateral,
        uint256 _edgeAmountToBurn
    ) external {
        _burnEdge(_edgeAmountToBurn, msg.sender, msg.sender);
        _withdrawCollateral(_collateralAddress, _amountCollateral, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @param _collateralAddress The address of the token to deposit.
     * @param _amount The amount of collateral to deposit.
     */
    function depositCollateral(address _collateralAddress, uint256 _amount)
        public
        amountGreaterThanZero(_amount)
        isAllowedCollateral(_collateralAddress)
    {
        s_collateralDeposits[msg.sender][_collateralAddress] += _amount;
        emit CollateralDeposited(msg.sender, _collateralAddress, _amount);

        bool success = ERC20(_collateralAddress).transferFrom(msg.sender, address(this), _amount);
        if (!success) revert EdgeEngine__FailedToDepositCollateral();
    }

    /**
     * @param _amount Amount of Edge to mint.
     * @dev Must have sufficient collateral value to maintain Health Factor.
     */
    function mintEdge(uint256 _amount) public amountGreaterThanZero(_amount) noCollatatralDeposited(msg.sender) {
        s_mintedEdge[msg.sender] += _amount;
        _revertIfHealthFactorIsBroken(msg.sender);

        bool success = i_edge.mint(msg.sender, _amount);
        if (!success) revert EdgeEngine__FailedTo_MintEDGE();
        emit EdgeMinted(msg.sender, _amount);
    }

    /**
     * @param _amount Amount of Edge to burn from user's balance to improve Health Factor.
     */
    function burnEdge(uint256 _amount) external amountGreaterThanZero(_amount) noCollatatralDeposited(msg.sender) {
        _burnEdge(_amount, msg.sender, msg.sender);
        // Burning Edge always improves health factor, so revert check is optional but safe
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @param _collateralAddress Token to withdraw.
     * @param _amount Amount to withdraw.
     */
    function withdrawCollateral(address _collateralAddress, uint256 _amount)
        external
        amountGreaterThanZero(_amount)
        noCollatatralDeposited(msg.sender)
    {
        _withdrawCollateral(_collateralAddress, _amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice Liquidates a user whose Health Factor is below 1.
     * @param _user The broken user address.
     * @param _token The collateral token to seize.
     * @param _debtToCover The amount of Edge you want to burn to improve user's debt.
     */
    function liquidate(address _user, address _token, uint256 _debtToCover)
        external
        amountGreaterThanZero(_debtToCover)
    {
        uint256 startingHealthFactor = getHealthFactor(_user);
        if (startingHealthFactor >= MIN_HEALTH_FACTOR) {
            revert EdgeEngine__UserHealthFactorIsOk();
        }

        // Calculate collateral equivalent of the debt plus bonus
        uint256 tokenAmountFromDebtCovered = getTokenValueFromUsd(_token, _debtToCover);
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATOR_BONUS) / LIQUIDATOR_BONUS_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;

        _burnEdge(_debtToCover, msg.sender, _user);
        _withdrawCollateral(_token, totalCollateralToRedeem, _user, msg.sender);

        uint256 endingHealthFactor = getHealthFactor(_user);
        if (endingHealthFactor <= startingHealthFactor) {
            revert EdgeEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    ///////////////////
    // Private/Internal Functions
    ///////////////////

    function _burnEdge(uint256 _amount, address _from, address _onBehalfOf) private {
        s_mintedEdge[_onBehalfOf] -= _amount;
        bool success = i_edge.transferFrom(_from, address(this), _amount);
        if (!success) revert EdgeEngine__FailedTo_TarnsferEDGEToBeBurn();
        i_edge.burn(_amount);
        emit EdgeBurned(_onBehalfOf, _amount);
    }

    function _withdrawCollateral(address _token, uint256 _amount, address _from, address _to) private {
        if (s_collateralDeposits[_from][_token] < _amount) {
            revert EdgeEngine__WithdrawExeedBalance();
        }

        s_collateralDeposits[_from][_token] -= _amount;
        emit CollateralWithdrawn(_from, _token, _amount);

        bool success = ERC20(_token).transfer(_to, _amount);
        if (!success) revert EdgeEngine__FaildToTransferCollateral();
    }

    function _revertIfHealthFactorIsBroken(address _user) internal view {
        uint256 healthFactor = getHealthFactor(_user);
        if (healthFactor < MIN_HEALTH_FACTOR) {
            revert EdgeEngine__HealthFatorIsBroken__LiquidatingSoon();
        }
    }

    ///////////////////
    // Public/View Functions
    ///////////////////

    function getHealthFactor(address _user) public view returns (uint256) {
        (uint256 collateralValueInUsd, uint256 totalMinted) = getAccountInformation(_user);
        if (totalMinted == 0) return type(uint256).max;

        uint256 adjustedCollateral = (collateralValueInUsd * THRESHOLD) / THRESHOLD_PRECISION;
        // if(adjustedCollateral <  totalMinted){
        //     revert EdgeEngine__MintingMoreThanCollateralAllowed();
        // }

        return (adjustedCollateral * PRECISION) / totalMinted;
    }

    function getAccountInformation(address _user)
        public
        view
        returns (uint256 collateralValueInUsd, uint256 totalMinted)
    {
        totalMinted = s_mintedEdge[_user];
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            collateralValueInUsd += getUsdValue(token, s_collateralDeposits[_user][token]);
        }
    }

    function getUsdValue(address _token, uint256 _amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[_token]);
        (, int256 price,,,) = priceFeed.getPriceFeedData();
        return ((uint256(price) * ORACLE_PRICE_PRECISION) * _amount) / PRECISION;
    }

    function getTokenValueFromUsd(address _token, uint256 _usdAmountInWei) public view isAllowedCollateral(_token)  returns (uint256)  {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[_token]);
        (, int256 price,,,) = priceFeed.getPriceFeedData();
        return (_usdAmountInWei * PRECISION) / (uint256(price) * ORACLE_PRICE_PRECISION);
    }

    function getCollatralWorthOfEdgeAndEgdeMintedSoFar(address _user) public view returns (uint256, uint256) {
        (uint256 collateralValueInUsd, uint256 totalMinted) = getAccountInformation(_user);

        uint256 adjustedCollateral = (collateralValueInUsd * THRESHOLD) / THRESHOLD_PRECISION;
        return (adjustedCollateral, totalMinted);
    }

    // Getters
    function getCollateralBalance(address _user, address _token) external view returns (uint256) {
        return s_collateralDeposits[_user][_token];
    }

    function getCollateralTokenPriceFeedAddress(address _token) external view returns (address collateral) {
        return s_priceFeeds[_token];
    }

    function getUserEdgeMinted(address user) external view returns (uint256) {
        return s_mintedEdge[user];
    }

    function getCollarteralAddress(uint256 _index) external view returns (address) {
        return s_collateralTokens[_index];
    }

    function getEdgeAddress() external view returns (address) {
        return address(i_edge);
    }

    function getOraclePricePrecision() external pure returns (uint256) {
        return ORACLE_PRICE_PRECISION;
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getThreshold() external pure returns (uint256) {
        return THRESHOLD;
    }

    function getThresholdPrecision() external pure returns (uint256) {
        return THRESHOLD_PRECISION;
    }

    function getLiquidatorBonus() external pure returns (uint256) {
        return LIQUIDATOR_BONUS;
    }

    function getLiquidatorBonusPrecision() external pure returns (uint256) {
        return LIQUIDATOR_BONUS_PRECISION;
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }
}
