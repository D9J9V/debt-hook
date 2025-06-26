// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "./interfaces/IERC20.sol";
import {IERC20Permit} from "./interfaces/IERC20Permit.sol";
import {IDebtHook} from "./interfaces/IDebtHook.sol";
import {IDebtOrderBook} from "./interfaces/IDebtOrderBook.sol";

/**
 * @title USDCPaymasterIntegration
 * @notice Integrates Circle's USDC Paymaster to enable gas-free transactions for DebtHook users
 * @dev This contract acts as a wrapper to prepare transactions for EIP-4337 account abstraction
 */
contract USDCPaymasterIntegration {
    /// @notice Circle's USDC Paymaster address on target network
    address public immutable PAYMASTER;
    
    /// @notice USDC token address
    address public immutable USDC;
    
    /// @notice DebtHook contract
    IDebtHook public immutable debtHook;
    
    /// @notice DebtOrderBook contract
    IDebtOrderBook public immutable debtOrderBook;
    
    /// @notice Event emitted when a gasless transaction is prepared
    event GaslessTransactionPrepared(
        address indexed user,
        uint256 gasCostInUSDC,
        bytes permitSignature
    );
    
    /**
     * @notice Constructor
     * @param _paymaster Circle's USDC Paymaster address
     * @param _usdc USDC token address
     * @param _debtHook DebtHook contract address
     * @param _debtOrderBook DebtOrderBook contract address
     */
    constructor(
        address _paymaster,
        address _usdc,
        address _debtHook,
        address _debtOrderBook
    ) {
        PAYMASTER = _paymaster;
        USDC = _usdc;
        debtHook = IDebtHook(_debtHook);
        debtOrderBook = IDebtOrderBook(_debtOrderBook);
    }
    
    /**
     * @notice Prepares paymaster data for a gasless loan acceptance
     * @param orderIndex The index of the order to accept
     * @param permitAmount Amount of USDC to approve for gas payment
     * @param deadline Permit deadline
     * @param v Permit signature v
     * @param r Permit signature r
     * @param s Permit signature s
     * @return paymasterData Encoded data for the paymaster
     */
    function prepareGaslessAcceptOrder(
        uint256 orderIndex,
        uint256 permitAmount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external view returns (bytes memory paymasterData) {
        // Create permit signature
        bytes memory permitSignature = abi.encodePacked(r, s, v);
        
        // Encode paymaster data according to Circle's specification
        // Flag 0 indicates USDC payment mode
        paymasterData = abi.encodePacked(
            uint8(0),           // Flag for USDC payment
            USDC,              // Token address
            permitAmount,      // Amount to approve
            permitSignature    // EIP-2612 permit signature
        );
        
        return paymasterData;
    }
    
    /**
     * @notice Prepares paymaster data for a gasless loan repayment
     * @param loanId The ID of the loan to repay
     * @param amount Amount to repay
     * @param permitAmount Amount of USDC to approve for gas payment
     * @param deadline Permit deadline
     * @param v Permit signature v
     * @param r Permit signature r
     * @param s Permit signature s
     * @return paymasterData Encoded data for the paymaster
     */
    function prepareGaslessRepayment(
        uint256 loanId,
        uint256 amount,
        uint256 permitAmount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external view returns (bytes memory paymasterData) {
        // Create permit signature
        bytes memory permitSignature = abi.encodePacked(r, s, v);
        
        // Encode paymaster data
        paymasterData = abi.encodePacked(
            uint8(0),           // Flag for USDC payment
            USDC,              // Token address
            permitAmount,      // Amount to approve for gas
            permitSignature    // EIP-2612 permit signature
        );
        
        return paymasterData;
    }
    
    /**
     * @notice Helper to estimate gas cost in USDC for a transaction
     * @param gasLimit Estimated gas limit for the transaction
     * @param maxFeePerGas Maximum fee per gas in wei
     * @param ethPriceInUSDC Current ETH price in USDC (6 decimals)
     * @return gasCostInUSDC Estimated gas cost in USDC
     */
    function estimateGasCostInUSDC(
        uint256 gasLimit,
        uint256 maxFeePerGas,
        uint256 ethPriceInUSDC
    ) external pure returns (uint256 gasCostInUSDC) {
        // Calculate gas cost in ETH
        uint256 gasCostInWei = gasLimit * maxFeePerGas;
        
        // Convert to USDC (accounting for decimals: ETH=18, USDC=6)
        // gasCostInUSDC = (gasCostInWei * ethPriceInUSDC) / 10^18
        gasCostInUSDC = (gasCostInWei * ethPriceInUSDC) / 1e18;
        
        // Add 10% buffer for price fluctuations
        gasCostInUSDC = (gasCostInUSDC * 110) / 100;
        
        return gasCostInUSDC;
    }
    
    /**
     * @notice Generates the EIP-712 domain separator for USDC permits
     * @return domainSeparator The domain separator
     */
    function getUSDCDomainSeparator() external view returns (bytes32) {
        return IERC20Permit(USDC).DOMAIN_SEPARATOR();
    }
}