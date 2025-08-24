// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ContractErrors.sol";

library MembershipLib {
    struct MembershipPlan {
        uint256 price;
        string name;
        uint256 membersPerCycle;
        bool isActive;
    }

    struct Member {
        address upline;
        uint256 totalReferrals;
        uint256 totalEarnings;
        uint256 planId;
        uint256 cycleNumber;
        uint256 registeredAt;
    }

    struct CycleInfo {
        uint256 currentCycle;
        uint256 membersInCurrentCycle;
    }

    function isUnlimitedPlan(uint256 planId) internal pure returns (bool) {
        return planId == 0;
    }

    function hasAccessToPlan(uint256 memberPlanId, uint256 requiredPlanId) internal pure returns (bool) {
        if (memberPlanId == 0) {
            return true;
        }
        return memberPlanId >= requiredPlanId;
    }

    function updateCycle(
        CycleInfo storage cycleInfo,
        MembershipPlan storage plan
    ) internal returns (uint256) {
        cycleInfo.membersInCurrentCycle++;
        
        if (cycleInfo.membersInCurrentCycle >= plan.membersPerCycle) {
            cycleInfo.currentCycle++;
            cycleInfo.membersInCurrentCycle = 0;
        }
        
        return cycleInfo.currentCycle;
    }

    function validatePlanUpgrade(
        uint256 newPlanId,
        Member storage currentMember,
        mapping(uint256 => MembershipPlan) storage plans,
        uint256 planCount,
        bool isOwner
    ) internal view {
        if (newPlanId == 0 || newPlanId > planCount) revert ContractErrors.InvalidPlanID();
        if (!plans[newPlanId].isActive) revert ContractErrors.InactivePlan();
        
        if (isOwner && currentMember.planId == 0) {
            return;
        }
        
        if (!isOwner && newPlanId != currentMember.planId + 1) {
            revert ContractErrors.NextPlanOnly();
        }
        
        if (isOwner && newPlanId <= currentMember.planId) {
            revert ContractErrors.InvalidPlanID();
        }
    }

    function determineUpline(
        address upline,
        uint256 planId,
        address sender,
        address contractOwner,
        mapping(address => Member) storage members,
        function(address) external view returns (uint256) getBalance
    ) internal view returns (address) {
        if (upline == address(0) || upline == sender) {
            return contractOwner;
        }
        
        if (upline == contractOwner) {
            return upline;
        }
        
        if (getBalance(upline) == 0) {
            revert ContractErrors.UplineNotMember();
        }
        
        if (!hasAccessToPlan(members[upline].planId, planId)) {
            revert ContractErrors.UplinePlanLow();
        }
        
        return upline;
    }

    function validateUplineForOwner(
        address upline,
        address owner,
        mapping(address => Member) storage members
    ) internal view returns (bool) {
        if (upline == owner) {
            return true;
        }
        
        return members[upline].planId > 0;
    }

    function getMaxUplinePlan(uint256 memberPlanId) internal pure returns (uint256) {
        if (memberPlanId == 0) {
            return type(uint256).max;
        }
        return memberPlanId;
    }

    function getDisplayPlanId(uint256 planId) internal pure returns (string memory) {
        if (planId == 0) {
            return "ROOT";
        }
        return string(abi.encodePacked("Plan ", _uint2str(planId)));
    }

    function _uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) return "0";
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            unchecked { ++len; }
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            unchecked { k = k - 1; }
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}
