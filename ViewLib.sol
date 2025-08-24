// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./MembershipLib.sol";
import "./GrowthCommissionLib.sol";

library ViewLib {
    function getSystemStats(
        uint256 totalSupply,
        uint256 ownerBalance,
        uint256 feeBalance,
        uint256 fundBalance,
        uint256 totalCommissionPaid,
        uint256 growthCommissionPaid
    ) internal pure returns (
        uint256 totalMembers,
        uint256 totalRevenue,
        uint256 totalCommission,
        uint256 ownerFunds,
        uint256 feeFunds,
        uint256 fundFunds
    ) {
        totalMembers = totalSupply;
        totalRevenue = ownerBalance + feeBalance + fundBalance + totalCommissionPaid + growthCommissionPaid;
        totalCommission = totalCommissionPaid + growthCommissionPaid;
        ownerFunds = ownerBalance;
        feeFunds = feeBalance;
        fundFunds = fundBalance;
    }

    function getContractStatus(
        bool paused,
        IERC20 token,
        uint256 totalSupply,
        uint256 planCount,
        uint256 emergencyRequestTime,
        uint256 timelockDuration
    ) internal view returns (
        bool isPaused,
        uint256 totalBalance,
        uint256 memberCount,
        uint256 currentPlanCount,
        bool hasEmergencyRequest,
        uint256 emergencyTimeRemaining
    ) {
        isPaused = paused;
        totalBalance = token.balanceOf(address(this));
        memberCount = totalSupply;
        currentPlanCount = planCount;
        hasEmergencyRequest = emergencyRequestTime > 0;
        emergencyTimeRemaining = emergencyRequestTime > 0 
            ? (emergencyRequestTime + timelockDuration > block.timestamp 
                ? emergencyRequestTime + timelockDuration - block.timestamp 
                : 0)
            : 0;
    }

    function validateContractBalance(
        IERC20 token,
        uint256 ownerBalance,
        uint256 feeBalance,
        uint256 fundBalance
    ) internal view returns (bool isValid, uint256 expectedBalance, uint256 actualBalance) {
        expectedBalance = ownerBalance + feeBalance + fundBalance;
        actualBalance = token.balanceOf(address(this));
        isValid = actualBalance >= expectedBalance;
    }

    function getPlanInfo(
        mapping(uint256 => MembershipLib.MembershipPlan) storage plans,
        mapping(uint256 => string) storage planDefaultImages,
        uint256 planId,
        uint256 planCount
    ) internal view returns (
        uint256 price,
        string memory name,
        uint256 membersPerCycle,
        bool isActive,
        string memory imageURI
    ) {
        if (planId == 0 || planId > planCount) revert ContractErrors.InvalidPlanID();
        MembershipLib.MembershipPlan memory plan = plans[planId];
        return (plan.price, plan.name, plan.membersPerCycle, plan.isActive, planDefaultImages[planId]);
    }

    function getMemberDisplayPlanId(
        mapping(address => MembershipLib.Member) storage members,
        address member,
        address owner
    ) internal view returns (uint256) {
        return member == owner && members[member].planId == 0 ? 999 : members[member].planId;
    }
}
