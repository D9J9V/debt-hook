// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {UserOperation} from "./UserOperation.sol";

/**
 * @title IPaymaster
 * @notice EIP-4337 Paymaster interface
 */
interface IPaymaster {
    enum PostOpMode {
        opSucceeded,
        opReverted,
        postOpReverted
    }

    /**
     * @notice Validates a paymaster user operation
     * @param userOp The user operation
     * @param userOpHash Hash of the user operation
     * @param maxCost Maximum cost of the operation
     * @return context Context to pass to postOp
     * @return validationData Validation data (0 for success)
     */
    function validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external returns (bytes memory context, uint256 validationData);

    /**
     * @notice Post-operation handler
     * @param mode Whether the operation succeeded
     * @param context Context from validatePaymasterUserOp
     * @param actualGasCost Actual gas cost of the operation
     */
    function postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost
    ) external;
}