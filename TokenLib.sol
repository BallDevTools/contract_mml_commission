// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./ContractErrors.sol";

library TokenLib {
    using SafeERC20 for IERC20;

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal {
        uint256 balanceBefore = token.balanceOf(to);
        token.safeTransferFrom(from, to, amount);
        
        if (token.balanceOf(to) < balanceBefore + amount) 
            revert ContractErrors.InvalidAmount();
    }

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 amount
    ) internal {
        uint256 balanceBefore = token.balanceOf(to);
        token.safeTransfer(to, amount);
        
        if (token.balanceOf(to) < balanceBefore + amount) 
            revert ContractErrors.InvalidAmount();
    }

    function validateWithdrawal(
        uint256 requestedAmount,
        uint256 availableBalance
    ) internal pure {
        if (requestedAmount > availableBalance) {
            revert ContractErrors.LowFundBalance();
        }
    }
}