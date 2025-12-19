// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {
    AggregatorV3Interface
} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
/**
 * @title EdgeEngine
 * @author Himxa
 * @notice thinking.
 */
contract EdgeEngine {
    ///////////////////
    // Errors
    ///////////////////
    error EdgeEngine__MustBeGreaterThanZero();
    error EdgeEngine__CollateralTokenNotAllowed();
    error EdgeEngine__FailedToDepositCollateral();
    error EdgeEngine__CollateralAddressAndPriceFeedLengthMismatch();

    ///////////////////
    // State Variables
    ///////////////////
    // Mapping of token address to its corresponding Price Feed address
    mapping(address collateralToken => address priceFeed) private s_priceFeeds;
    address[] private s_collateralTokens;

    // Mapping of user address to collateral token address to the amount deposited
    mapping(address user => mapping(address collateralToken => uint256 amount))
        private s_collateralDeposits;
    uint256 private constant ORACLE_PRICE_PRICISION = 1e10;
    uint256 private constant PRICE_PRICISION = 1e18;

    ///////////////////
    // Events
    ///////////////////
    event CollateralDeposited(
        address indexed user,
        address indexed collateral,
        uint256 indexed amount
    );

    ///////////////////
    // Modifiers
    ///////////////////
    modifier minimumChecks(uint256 _amount) {
        if (_amount <= 0) {
            revert EdgeEngine__MustBeGreaterThanZero();
        }
        _;
    }

    modifier isCollateralAllowed(address _collateral) {
        if (s_priceFeeds[_collateral] == address(0)) {
            revert EdgeEngine__CollateralTokenNotAllowed();
        }
        _;
    }

    ///////////////////
    // Functions
    ///////////////////

    constructor(
        address[] memory _collateralTokens,
        address[] memory _priceFeeds
    ) {
        if (_collateralTokens.length != _priceFeeds.length) {
            revert EdgeEngine__CollateralAddressAndPriceFeedLengthMismatch();
        }

        for (uint256 i = 0; i < _collateralTokens.length; i++) {
            s_priceFeeds[_collateralTokens[i]] = _priceFeeds[i];
            s_collateralTokens.push(_collateralTokens[i]);
        }
    }

    ///////////////////
    // External Functions
    ///////////////////

    /**
     * @param _collateralAddress The address of the token to deposit as collateral
     * @param _amount The amount of collateral to deposit
     * @dev user parameter removed from input as msg.sender is more secure for deposits
     */
    function depositCollateral(
        address _collateralAddress,
        uint256 _amount
    ) external minimumChecks(_amount) isCollateralAllowed(_collateralAddress) {
        // Update state before external transfer (Checks-Effects-Interactions pattern)
        s_collateralDeposits[msg.sender][_collateralAddress] += _amount;

        emit CollateralDeposited(msg.sender, _collateralAddress, _amount);

        // Perform the transfer
        bool success = ERC20(_collateralAddress).transferFrom(
            msg.sender,
            address(this),
            _amount
        );

        if (!success) {
            revert EdgeEngine__FailedToDepositCollateral();
        }
    }

    function getAccountInfomation(
        address user
    )
        external
        view
        returns (uint256 collateralValueInUsd, uint256 totalCollateral)
    {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            totalCollateral += s_collateralDeposits[user][token];
            collateralValueInUsd += getCollaterTokenPrice(
                token,
                s_collateralDeposits[user][token]
            );
        }
        return (collateralValueInUsd, totalCollateral);
    }

    function getCollaterTokenPrice(
        address _collateralTokenAddress,
        uint256 _amount
    ) internal view returns (uint256 price) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[_collateralTokenAddress]
        );
        (, int256 priceValue, , , ) = priceFeed.latestRoundData();

        return
            ((uint256(priceValue) * ORACLE_PRICE_PRICISION) * _amount) /
            PRICE_PRICISION;
    }

    ///////////////////
    // Getter Functions (Public/View)
    ///////////////////

    function getCollateralBalance(
        address user,
        address token
    ) external view returns (uint256) {
        return s_collateralDeposits[user][token];
    }

    function getPriceFeed(address token) external view returns (address) {
        return s_priceFeeds[token];
    }
}
