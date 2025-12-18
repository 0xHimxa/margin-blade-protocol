// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract EdgeEngine {
    error EdgeEngine__MustBeGreaterThanZero();
    error EdgeEngine__CollateralTokenNotAllowed();

    error EdgeEngine__FailedToDeppositCollateral();
    error EdgeEngine__CollateralAdressAndPriceFeedLengthMismatch();

    event CollateralDeposited(
        address indexed user,
        address indexed collateral,
        uint256 indexed amount
    );

    mapping(address collatralToken => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address collateralToken => uint256))
        private s_Collateraldeposits;

    constructor(
        address[] memory _collateralTokens,
        address[] memory _priceFeeds
    ) {
        if (_collateralTokens.length != _priceFeeds.length) {
            revert EdgeEngine__CollateralAdressAndPriceFeedLengthMismatch();
        }

        for (uint256 i = 0; i < _collateralTokens.length; i++) {
            address token = _collateralTokens[i];
            address priceFeed = _priceFeeds[i];
            s_priceFeeds[token] = priceFeed;
        }
    }

    modifier minimunChecks(uint256 _amount) {
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

    function depositCollataral(
        address user,
        address _collateralAddress,
        uint256 _amount
    ) external minimunChecks(_amount) isCollateralAllowed(_collateralAddress) {
        s_Collateraldeposits[user][_collateralAddress] += _amount;

        emit CollateralDeposited(user, _collateralAddress, _amount);

        bool successFull = ERC20(_collateralAddress).transferFrom(
            msg.sender,
            address(this),
            _amount
        );

        if (!successFull) {
            revert EdgeEngine__FailedToDeppositCollateral();
        }
    }
}
