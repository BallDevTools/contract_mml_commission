// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./TokenLib.sol";
import "./ContractErrors.sol";

library AdminLib {
    using TokenLib for IERC20;

    struct WithdrawalRequest {
        address recipient;
        uint256 amount;
        uint256 balanceType; // 0=owner, 1=fee, 2=fund
    }

    event BatchWithdrawalProcessed(uint256 totalOwner, uint256 totalFee, uint256 totalFund);

    function processWithdrawal(
        IERC20 token,
        address recipient,
        uint256 amount,
        uint256 balanceType,
        uint256 ownerBalance,
        uint256 feeBalance,
        uint256 fundBalance
    ) internal returns (uint256 newOwnerBalance, uint256 newFeeBalance, uint256 newFundBalance) {
        if (balanceType == 0) {
            if (amount > ownerBalance) revert ContractErrors.LowOwnerBalance();
            newOwnerBalance = ownerBalance - amount;
            newFeeBalance = feeBalance;
            newFundBalance = fundBalance;
        } else if (balanceType == 1) {
            if (amount > feeBalance) revert ContractErrors.LowFeeBalance();
            newOwnerBalance = ownerBalance;
            newFeeBalance = feeBalance - amount;
            newFundBalance = fundBalance;
        } else {
            if (amount > fundBalance) revert ContractErrors.LowFundBalance();
            newOwnerBalance = ownerBalance;
            newFeeBalance = feeBalance;
            newFundBalance = fundBalance - amount;
        }
        
        token.safeTransfer(recipient, amount);
    }

    function processBatchWithdraw(
        IERC20 token,
        WithdrawalRequest[] calldata requests,
        uint256 ownerBalance,
        uint256 feeBalance,
        uint256 fundBalance
    ) internal returns (uint256 newOwnerBalance, uint256 newFeeBalance, uint256 newFundBalance) {
        if (requests.length == 0 || requests.length > 20) revert ContractErrors.InvalidRequests();

        uint256 totalOwner;
        uint256 totalFee;
        uint256 totalFund;

        newOwnerBalance = ownerBalance;
        newFeeBalance = feeBalance;
        newFundBalance = fundBalance;

        for (uint256 i = 0; i < requests.length;) {
            WithdrawalRequest calldata req = requests[i];
            if (req.recipient == address(0) || req.amount == 0) revert ContractErrors.InvalidRequest();

            (newOwnerBalance, newFeeBalance, newFundBalance) = processWithdrawal(
                token, req.recipient, req.amount, req.balanceType,
                newOwnerBalance, newFeeBalance, newFundBalance
            );

            if (req.balanceType == 0) totalOwner += req.amount;
            else if (req.balanceType == 1) totalFee += req.amount;
            else totalFund += req.amount;

            unchecked { ++i; }
        }

        emit BatchWithdrawalProcessed(totalOwner, totalFee, totalFund);
    }

    function validatePlanUpdate(uint256 planId, uint256 planCount) internal pure {
        if (planId == 0 || planId > planCount) revert ContractErrors.InvalidPlanID();
    }

    function processEmergencyWithdraw(
        IERC20 token,
        address owner,
        uint256 requestTime,
        uint256 timelockDuration
    ) internal returns (uint256 withdrawnAmount) {
        if (requestTime == 0) revert ContractErrors.NoRequest();
        if (block.timestamp < requestTime + timelockDuration) revert ContractErrors.TimelockActive();

        withdrawnAmount = token.balanceOf(address(this));
        if (withdrawnAmount == 0) revert ContractErrors.ZeroBalance();

        token.safeTransfer(owner, withdrawnAmount);
    }
}
