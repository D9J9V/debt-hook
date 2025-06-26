// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPaymaster} from "./interfaces/IPaymaster.sol";
import {IEntryPoint} from "./interfaces/IEntryPoint.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {IERC20Permit} from "./interfaces/IERC20Permit.sol";
import {UserOperation} from "./interfaces/UserOperation.sol";

/**
 * @title CirclePaymaster
 * @notice EIP-4337 Paymaster that accepts USDC as payment for gas fees
 * @dev Implements Circle's paymaster pattern for USDC gas payments
 */
contract CirclePaymaster is IPaymaster {
    // Constants
    uint256 private constant COST_OF_POST = 15000;
    
    // State variables
    IEntryPoint public immutable entryPoint;
    address public immutable owner;
    
    // Token configuration
    mapping(address => bool) public supportedTokens;
    mapping(address => uint256) public tokenPriceOracle; // Price in wei per token unit
    
    // Events
    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);
    event TokenPriceUpdated(address indexed token, uint256 price);
    event GasPayment(address indexed user, address indexed token, uint256 amount, uint256 gasCost);
    
    // Errors
    error OnlyOwner();
    error OnlyEntryPoint();
    error UnsupportedToken();
    error InvalidSignature();
    error InsufficientBalance();
    error InsufficientAllowance();
    
    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }
    
    modifier onlyEntryPoint() {
        if (msg.sender != address(entryPoint)) revert OnlyEntryPoint();
        _;
    }
    
    constructor(IEntryPoint _entryPoint, address _usdc) {
        entryPoint = _entryPoint;
        owner = msg.sender;
        
        // Add USDC as default supported token
        supportedTokens[_usdc] = true;
        tokenPriceOracle[_usdc] = 3000; // Initial price: 1 USDC = 3000 wei (adjustable)
        
        emit TokenAdded(_usdc);
    }
    
    /**
     * @notice Validates paymaster data and returns context for postOp
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
    ) external onlyEntryPoint returns (bytes memory context, uint256 validationData) {
        // Decode paymaster data
        (uint8 mode, address token, uint256 permitAmount, bytes memory permitSignature) = 
            abi.decode(userOp.paymasterAndData[20:], (uint8, address, uint256, bytes));
        
        if (!supportedTokens[token]) revert UnsupportedToken();
        
        // Mode 0: EIP-2612 permit
        if (mode == 0) {
            // Extract permit parameters
            (uint8 v, bytes32 r, bytes32 s) = _splitSignature(permitSignature);
            
            // Execute permit to set allowance
            try IERC20Permit(token).permit(
                userOp.sender,
                address(this),
                permitAmount,
                type(uint256).max, // deadline
                v,
                r,
                s
            ) {} catch {
                // Permit might fail if already set, check allowance
                uint256 allowance = IERC20(token).allowance(userOp.sender, address(this));
                if (allowance < maxCost * tokenPriceOracle[token] / 1e18) {
                    revert InsufficientAllowance();
                }
            }
        }
        
        // Check user has sufficient balance
        uint256 requiredTokens = maxCost * tokenPriceOracle[token] / 1e18;
        if (IERC20(token).balanceOf(userOp.sender) < requiredTokens) {
            revert InsufficientBalance();
        }
        
        // Return context for postOp
        context = abi.encode(userOp.sender, token, maxCost);
        validationData = 0; // Always return 0 for valid
    }
    
    /**
     * @notice Handles payment after operation execution
     * @param mode PostOp mode (success/revert)
     * @param context Context from validatePaymasterUserOp
     * @param actualGasCost Actual gas cost of the operation
     */
    function postOp(
        IPaymaster.PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost
    ) external onlyEntryPoint {
        (address user, address token, uint256 maxCost) = abi.decode(context, (address, address, uint256));
        
        // Calculate actual token amount to charge
        uint256 actualTokenCost = actualGasCost * tokenPriceOracle[token] / 1e18;
        
        // Transfer tokens from user to paymaster
        bool success = IERC20(token).transferFrom(user, address(this), actualTokenCost);
        require(success, "Token transfer failed");
        
        emit GasPayment(user, token, actualTokenCost, actualGasCost);
        
        // Refund EntryPoint for gas costs
        entryPoint.depositTo{value: actualGasCost}(address(this));
    }
    
    /**
     * @notice Deposits ETH to the EntryPoint for this paymaster
     */
    function deposit() external payable {
        entryPoint.depositTo{value: msg.value}(address(this));
    }
    
    /**
     * @notice Withdraws ETH from the EntryPoint
     * @param withdrawAddress Address to withdraw to
     * @param amount Amount to withdraw
     */
    function withdrawTo(address payable withdrawAddress, uint256 amount) external onlyOwner {
        entryPoint.withdrawTo(withdrawAddress, amount);
    }
    
    /**
     * @notice Updates token price oracle
     * @param token Token address
     * @param price Price in wei per token unit
     */
    function updateTokenPrice(address token, uint256 price) external onlyOwner {
        require(supportedTokens[token], "Token not supported");
        tokenPriceOracle[token] = price;
        emit TokenPriceUpdated(token, price);
    }
    
    /**
     * @notice Adds support for a new token
     * @param token Token address
     * @param price Initial price in wei per token unit
     */
    function addToken(address token, uint256 price) external onlyOwner {
        supportedTokens[token] = true;
        tokenPriceOracle[token] = price;
        emit TokenAdded(token);
    }
    
    /**
     * @notice Removes support for a token
     * @param token Token address
     */
    function removeToken(address token) external onlyOwner {
        supportedTokens[token] = false;
        emit TokenRemoved(token);
    }
    
    /**
     * @notice Withdraws accumulated tokens
     * @param token Token to withdraw
     * @param to Address to send tokens to
     * @param amount Amount to withdraw
     */
    function withdrawToken(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).transfer(to, amount);
    }
    
    /**
     * @notice Splits signature into v, r, s components
     */
    function _splitSignature(bytes memory sig) private pure returns (uint8 v, bytes32 r, bytes32 s) {
        require(sig.length == 65, "Invalid signature length");
        
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }
    
    /**
     * @notice Gets the current deposit for this paymaster in the EntryPoint
     */
    function getDeposit() external view returns (uint256) {
        return entryPoint.balanceOf(address(this));
    }
    
    receive() external payable {
        // Accept ETH deposits
    }
}