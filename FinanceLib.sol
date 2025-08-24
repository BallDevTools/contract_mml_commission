// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library FinanceLib {
    uint256 private constant HUNDRED_PERCENT = 100;
    uint256 private constant COMPANY_OWNER_SHARE = 80;
    uint256 private constant COMPANY_FEE_SHARE = 20;
    uint256 private constant USER_UPLINE_SHARE = 60;
    uint256 private constant USER_FUND_SHARE = 40;

    function getPlanShares(uint256 planId) internal pure returns (uint256 userShare, uint256 companyShare) {
        if (planId <= 4) {
            return (50, 50);
        } else if (planId <= 8) {
            return (55, 45);
        } else if (planId <= 12) {
            return (58, 42);
        } else {
            return (60, 40);
        }
    }

    function distributeFunds(uint256 _amount, uint256 _currentPlanId)
        internal
        pure
        returns (
            uint256 ownerShare,
            uint256 feeShare,
            uint256 fundShare,
            uint256 uplineShare
        )
    {
        require(_amount > 0, "Invalid amount");

        (uint256 userSharePercent, uint256 companySharePercent) = getPlanShares(_currentPlanId);
        require(userSharePercent + companySharePercent == HUNDRED_PERCENT, "Invalid shares total");

        uint256 userShare;
        uint256 companyShare;
        unchecked {
            userShare = (_amount * userSharePercent) / HUNDRED_PERCENT;
            companyShare = _amount - userShare;
        }

        require(userShare + companyShare == _amount, "Distribution calculation error");

        unchecked {
            ownerShare = (companyShare * COMPANY_OWNER_SHARE) / HUNDRED_PERCENT;
            feeShare = companyShare - ownerShare;
            uplineShare = (userShare * USER_UPLINE_SHARE) / HUNDRED_PERCENT;
            fundShare = userShare - uplineShare;
        }
    }
}
