// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library ContractErrors {
    error Paused();
    error NotMember();
    error ReentrantTransfer();
    error ZeroAddress();
    error NonTransferable();

    error InvalidCycleMembers();
    error EmptyName();
    error ZeroPrice();
    error PriceTooLow();
    error InvalidPlanID();
    error EmptyURI();
    error InactivePlan();
    error NextPlanOnly();
    error NoPlanImage();
    error Plan1Only();

    error NonexistentToken();

    error AlreadyMember();
    error ThirtyDayLock();
    error UplinePlanLow();
    error UplineNotMember();

    error InvalidAmount();
    error LowOwnerBalance();
    error LowFeeBalance();
    error LowFundBalance();
    error InvalidRequest();
    error InvalidRequests();
    error InvalidShares();
    error DistributionError();
    error InvalidDecimals();

    error NoRequest();
    error TimelockActive();
    error ZeroBalance();
    error NotPaused();
}