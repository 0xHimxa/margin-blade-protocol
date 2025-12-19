// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


abstract contract EdgeEngineErrors{
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




}