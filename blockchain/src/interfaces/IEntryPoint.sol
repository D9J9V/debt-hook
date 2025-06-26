// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {UserOperation} from "./UserOperation.sol";

/**
 * @title IEntryPoint
 * @notice EIP-4337 EntryPoint interface
 */
interface IEntryPoint {
    /**
     * @notice Deposits ETH to the specified address's stake
     * @param account The account to deposit for
     */
    function depositTo(address account) external payable;

    /**
     * @notice Withdraws ETH from the account's stake
     * @param withdrawAddress Address to withdraw to
     * @param withdrawAmount Amount to withdraw
     */
    function withdrawTo(address payable withdrawAddress, uint256 withdrawAmount) external;

    /**
     * @notice Gets the balance of an account
     * @param account The account to check
     * @return The account's balance
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @notice Executes a batch of user operations
     * @param ops Array of user operations to execute
     * @param beneficiary Address to receive gas payments
     */
    function handleOps(UserOperation[] calldata ops, address payable beneficiary) external;

    /**
     * @notice Gets the user operation hash
     * @param userOp The user operation
     * @return The operation hash
     */
    function getUserOpHash(UserOperation calldata userOp) external view returns (bytes32);
}