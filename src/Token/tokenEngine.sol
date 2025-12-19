// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {
    AggregatorV3Interface
} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Edge} from "./Edge-Token.sol";
import {EdgeEngineErrors} from "./abstrat-contracts/abstractEdgengine.sol";
/**
 * @title EdgeEngine
 * @author Himxa
 * @notice thinking.
 */
contract EdgeEngine is EdgeEngineErrors {
    ///////////////////
    // State Variables
    ///////////////////
    // Mapping of token address to its corresponding Price Feed address
    mapping(address collateralToken => address priceFeed) private s_priceFeeds;
    address[] private s_collateralTokens;
    mapping(address user => uint256 minted) private s_minteds;

    // Mapping of user address to collateral token address to the amount deposited
    mapping(address user => mapping(address collateralToken => uint256 amount))
        private s_collateralDeposits;
    uint256 private constant ORACLE_PRICE_PRICISION = 1e10;
    uint256 private constant PRICE_PRICISION = 1e18;
    uint256 private constant THRESHOLD = 50;
    uint256 private constant THRESHOLD_PRICISIONS = 100;
    Edge private immutable edge;
    ///////////////////
    // Events
    ///////////////////
    event CollateralDeposited(
        address indexed user,
        address indexed collateral,
        uint256 indexed amount
    );

    event userWithDrawCollateral(
        address indexed user,
        address indexed collateralAdd,
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
        address[] memory _priceFeeds,
        address _edgeAddress
    ) {
        if (_collateralTokens.length != _priceFeeds.length) {
            revert EdgeEngine__CollateralAddressAndPriceFeedLengthMismatch();
        }

        if (_edgeAddress == address(0))
            revert EdgeEngine__EdgeContractCantbeAddressZero();

        edge = Edge(_edgeAddress);

        for (uint256 i = 0; i < _collateralTokens.length; i++) {
            s_priceFeeds[_collateralTokens[i]] = _priceFeeds[i];
            s_collateralTokens.push(_collateralTokens[i]);
        }
    }

    function depositCollateralAndMintEdge(
        address _collateralAddress,
        uint256 _amountCollateral,
        uint256 _edgeAmountToMint
    ) public {
        depositCollateral(_collateralAddress, _amountCollateral);
        mintEdge(_edgeAmountToMint);
    }

    function withdrawCollateralAndBurnEdge(
        address _collateralAddress,
        uint256 _amountCollateral,
        uint256 _edgeAmountToBurn
    ) public {
        _burnEdge(_edgeAmountToBurn, msg.sender, msg.sender);
        _withdraw(_collateralAddress, _amountCollateral);

    _revertIFHealthFatorIsBroken(msg.sender);
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
    ) public minimumChecks(_amount) isCollateralAllowed(_collateralAddress) {
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

    function mintEdge(uint256 _amount) public minimumChecks(_amount) {
        s_minteds[msg.sender] += _amount;
        _revertIFHealthFatorIsBroken(msg.sender);

        bool success = edge.mint(msg.sender, _amount);

        if (!success) {
            revert EdgeEngine__FailedTo_MintEDGE();
        }
    }

    //check about paying more than they owled
    function burnEdge(uint256 _amount) public {
        _burnEdge(_amount, msg.sender, msg.sender);

        _revertIFHealthFatorIsBroken(msg.sender);
    }

    function _burnEdge(
        uint256 _amount,
        address from,
        address onBehalfOf
    ) private minimumChecks(_amount) {
        s_minteds[onBehalfOf] -= _amount;

        bool move = edge.transferFrom(from, address(this), _amount);
        if (!move) revert EdgeEngine__FailedTo_TarnsferEDGEToBeBurn();

        edge.burn(_amount);
    }

    function withdrawCollateral(
        address _collateralAddress,
        uint256 _amount
    ) public minimumChecks(_amount) isCollateralAllowed(_collateralAddress) {
    _withdraw(_collateralAddress, _amount);
        _revertIFHealthFatorIsBroken(msg.sender);

      
    }


    function _withdraw(address _collateralAddress, uint256 _amount) private{
            if (s_collateralDeposits[msg.sender][_collateralAddress] == 0)
            revert EdgeEngine__WithdrawBalanceIsZero();
        if (s_collateralDeposits[msg.sender][_collateralAddress] < _amount)
            revert EdgeEngine__WithdrawExeedBalance();

        s_collateralDeposits[msg.sender][_collateralAddress] -= _amount;
        emit userWithDrawCollateral(msg.sender, _collateralAddress, _amount);

  bool success = ERC20(_collateralAddress).transfer(msg.sender, _amount);

        if (!success) {
            revert EdgeEngine__FaildToTransferCollateral();
        }
        
    }

    function healthFator(address user) private view returns (uint256) {
        (
            uint256 collateralValueInUsd,
            uint256 totalMinted
        ) = getAccountInfomation(user);

        if (totalMinted == 0) return PRICE_PRICISION;

        uint256 allowedThreshold = (collateralValueInUsd * THRESHOLD) /
            THRESHOLD_PRICISIONS;

        uint pricision = (allowedThreshold * PRICE_PRICISION) / totalMinted;

        return pricision;
    }

    function _revertIFHealthFatorIsBroken(address user) private view {
        uint256 pricision = healthFator(user);

        if (pricision < PRICE_PRICISION) {
            revert EdgeEngine__HealthFatorIsBroken__LiquidatingSoon();
        }
    }

    function getAccountInfomation(
        address user
    ) public view returns (uint256 collateralValueInUsd, uint256 totalMinted) {
        totalMinted = s_minteds[user];
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];

            collateralValueInUsd += getCollaterTokenPrice(
                token,
                s_collateralDeposits[user][token]
            );
        }
        return (collateralValueInUsd, totalMinted);
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
