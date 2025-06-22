// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IDebtHook {
    struct CreateLoanParams {
        address lender;
        address borrower;
        uint256 principalAmount;
        uint256 collateralAmount;
        uint64 maturityTimestamp;
        uint32 interestRateBips;
    }

    // CAMBIO PRINCIPAL: La función ahora especifica que devolverá el ID del préstamo.
    function createLoan(
        CreateLoanParams calldata params
    ) external payable returns (bytes32 loanId);
}
