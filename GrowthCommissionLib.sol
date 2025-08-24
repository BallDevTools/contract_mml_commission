// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./TokenLib.sol";
import "./MembershipLib.sol";
import "./ContractErrors.sol";

library GrowthCommissionLib {
    using TokenLib for IERC20;

    struct GrowthCommissionStats {
        uint256 totalGrowthCommission;
        uint256 plan1Commissions;
        uint256 plan2Commissions;
        uint256 plan3Commissions;
        uint256 downlineCount;
    }

    struct GrowthCommissionState {
        bool enabled;
        uint256 totalPaid;
        mapping(uint256 => uint256) rates;
        mapping(address => GrowthCommissionStats) stats;
    }

    event GrowthCommissionPaid(
        address indexed newMember,
        address indexed milestoneLeader,
        uint256 commissionAmount,
        uint256 planLevel,
        uint256 timestamp
    );

    event GrowthCommissionSkipped(
        address indexed member,
        uint256 planLevel,
        string reason
    );

    event GrowthCommissionStatusUpdated(bool enabled);
    event GrowthCommissionRateUpdated(uint256 planId, uint256 rate);

    function initialize(GrowthCommissionState storage state) internal {
        state.enabled = true;
        state.rates[1] = 150; // 1.5%
        state.rates[2] = 200; // 2.0%
        state.rates[3] = 250; // 2.5%
        for (uint256 i = 4; i <= 16; i++) {
            state.rates[i] = 0;
        }
    }

    struct CommissionParams {
        address newMember;
        uint256 planId;
        uint256 ownerBalance;
        address owner;
    }

    function processCommission(
        GrowthCommissionState storage state,
        mapping(address => MembershipLib.Member) storage members,
        mapping(uint256 => MembershipLib.MembershipPlan) storage plans,
        CommissionParams memory params,
        IERC20 token
    ) internal returns (uint256 commission, uint256 newOwnerBalance) {
        if (params.planId > 3 || params.planId == 0 || !state.enabled) {
            return (0, params.ownerBalance);
        }

        uint256 commissionRate = state.rates[params.planId];
        if (commissionRate == 0) {
            return (0, params.ownerBalance);
        }

        address milestoneLeader = findMilestoneLeader(members, params.newMember, params.owner);
        if (milestoneLeader == address(0)) {
            emit GrowthCommissionSkipped(params.newMember, params.planId, "No qualified milestone leader found");
            return (0, params.ownerBalance);
        }

        commission = (plans[params.planId].price * commissionRate) / 10000;
        
        if (params.ownerBalance < commission) {
            emit GrowthCommissionSkipped(params.newMember, params.planId, "Insufficient owner balance");
            return (0, params.ownerBalance);
        }

        newOwnerBalance = params.ownerBalance - commission;
        state.totalPaid += commission;

        updateStats(state.stats[milestoneLeader], commission, params.planId);

        token.safeTransfer(milestoneLeader, commission);
        members[milestoneLeader].totalEarnings += commission;

        emit GrowthCommissionPaid(params.newMember, milestoneLeader, commission, params.planId, block.timestamp);
        
        return (commission, newOwnerBalance);
    }

    function findMilestoneLeader(
        mapping(address => MembershipLib.Member) storage members,
        address member,
        address owner
    ) internal view returns (address) {
        address directUpline = members[member].upline;
        if (directUpline == address(0)) {
            return address(0);
        }

        address grandparentUpline = members[directUpline].upline;
        if (grandparentUpline == address(0)) {
            return address(0);
        }

        if (isMilestoneLeader(members, grandparentUpline, owner)) {
            return grandparentUpline;
        }

        return address(0);
    }

    function isMilestoneLeader(
        mapping(address => MembershipLib.Member) storage members,
        address member,
        address owner
    ) internal view returns (bool) {
        if (member == owner && members[member].planId == 0) {
            return true;
        }
        return members[member].planId >= 8;
    }

    function updateStats(
        GrowthCommissionStats storage stats,
        uint256 commission,
        uint256 planId
    ) internal {
        stats.totalGrowthCommission += commission;
        stats.downlineCount++;
        
        if (planId == 1) {
            stats.plan1Commissions += commission;
        } else if (planId == 2) {
            stats.plan2Commissions += commission;
        } else if (planId == 3) {
            stats.plan3Commissions += commission;
        }
    }

    struct PreviewParams {
        address member;
        uint256 planId;
        uint256 ownerBalance;
        address owner;
    }

    function previewCommission(
        GrowthCommissionState storage state,
        mapping(address => MembershipLib.Member) storage members,
        mapping(uint256 => MembershipLib.MembershipPlan) storage plans,
        PreviewParams memory params
    ) internal view returns (uint256 commission, address recipient) {
        if (params.planId > 3 || params.planId == 0 || !state.enabled) {
            return (0, address(0));
        }

        uint256 commissionRate = state.rates[params.planId];
        if (commissionRate == 0) {
            return (0, address(0));
        }

        address milestoneLeader = findMilestoneLeader(members, params.member, params.owner);
        if (milestoneLeader == address(0)) {
            return (0, address(0));
        }

        commission = (plans[params.planId].price * commissionRate) / 10000;
        
        if (params.ownerBalance < commission) {
            return (0, address(0));
        }

        return (commission, milestoneLeader);
    }

    function setRate(
        GrowthCommissionState storage state,
        uint256 planId,
        uint256 rate
    ) internal {
        if (planId == 0 || planId > 16) {
            revert ContractErrors.InvalidPlanID();
        }
        if (rate > 1000) { // Maximum 10%
            revert ContractErrors.InvalidAmount();
        }
        
        state.rates[planId] = rate;
        emit GrowthCommissionRateUpdated(planId, rate);
    }

    function setStatus(GrowthCommissionState storage state, bool enabled) internal {
        state.enabled = enabled;
        emit GrowthCommissionStatusUpdated(enabled);
    }
}