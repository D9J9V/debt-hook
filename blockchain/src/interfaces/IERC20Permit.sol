// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "./IERC20.sol";

/**
 * @title IERC20Permit
 * @notice ERC20 Permit extension for gasless approvals (EIP-2612)
 */
interface IERC20Permit is IERC20 {
    /**
     * @notice Sets approval via signature
     * @param owner Token owner
     * @param spender Address to approve
     * @param value Amount to approve
     * @param deadline Permit deadline
     * @param v Signature v
     * @param r Signature r
     * @param s Signature s
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @notice Returns the current nonce for an address
     * @param owner Token owner
     * @return Current nonce
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @notice Returns the domain separator
     * @return Domain separator
     */
    function DOMAIN_SEPARATOR() external view returns (bytes32);
    
    /**
     * @notice Returns the permit version
     * @return Version string
     */
    function version() external view returns (string memory);
}