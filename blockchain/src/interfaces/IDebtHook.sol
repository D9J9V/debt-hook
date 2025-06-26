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

    struct LoanMatch {
        address lender;
        address borrower;
        uint256 principalAmount;
        uint256 interestRateBips;
        uint256 maturityTimestamp;
    }

    // CAMBIO PRINCIPAL: La función ahora especifica que devolverá el ID del préstamo.
    function createLoan(CreateLoanParams calldata params) external payable returns (bytes32 loanId);

    // Create multiple loans in batch from matched orders
    function createBatchLoans(
        LoanMatch[] calldata matches,
        bytes calldata operatorProof
    ) external returns (bytes32[] memory loanIds);
}
