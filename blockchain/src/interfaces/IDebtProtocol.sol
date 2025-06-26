// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IDebtProtocol {
    // --- Structs ---

    struct Loan {
        address borrower;
        address lender;
        uint256 principal;
        uint256 collateralAmount;
        uint64 startTime;
        uint64 duration;
        uint64 interestRate; // Annual rate in basis points
        bool isRepaid;
        bool isLiquidated;
    }

    struct LoanParams {
        address borrower;
        address lender;
        uint256 principal;
        uint64 duration;
        uint64 interestRate;
    }

    struct LiquidationData {
        address liquidator;
        uint256 loanId;
        uint256 collateralAmount;
        uint256 debtAmount;
        address lender;
        address borrower;
        bool isActive;
    }

    // --- Functions ---

    function createLoan(LoanParams calldata params) external payable returns (uint256 loanId);

    function repayLoan(uint256 loanId) external;

    function liquidateLoan(uint256 loanId) external;

    function calculateRepaymentAmount(Loan memory loan) external view returns (uint256);

    function isLiquidatable(Loan memory loan) external view returns (bool);

    function getEthPrice() external view returns (uint256);

    function getLoan(uint256 loanId) external view returns (Loan memory);

    function getBorrowerLoans(address borrower) external view returns (uint256[] memory);

    function getLenderLoans(address lender) external view returns (uint256[] memory);
}
