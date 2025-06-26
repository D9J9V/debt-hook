// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IDebtOrderBook {
    struct LoanLimitOrder {
        address lender;
        address token;
        uint256 principalAmount;
        uint256 collateralRequired;
        uint32 interestRateBips;
        uint64 maturityTimestamp;
        uint64 expiry;
        uint256 nonce;
    }

    event OrderFilled(bytes32 indexed orderHash, address indexed borrower, uint256 principalAmount);
    event OrderCancelled(uint256 indexed nonce, address indexed lender);

    function fillLimitOrder(LoanLimitOrder calldata order, bytes calldata signature) external payable;
    function cancelNonce(uint256 nonce) external;
    function usedNonces(uint256 nonce) external view returns (bool);
}