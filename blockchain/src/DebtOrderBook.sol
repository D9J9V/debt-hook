// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {EIP712} from "solady/utils/EIP712.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {IDebtHook} from "./interfaces/IDebtHook.sol";

contract DebtOrderBook is EIP712 {
    IDebtHook public immutable debtHook;
    ERC20 public immutable usdc;
    address public serviceManager; // DebtOrderServiceManager for EigenLayer integration

    mapping(uint256 => bool) public usedNonces;
    
    // Events for EigenLayer integration
    event OrderSubmittedToAVS(bytes32 indexed orderHash, address indexed lender);
    event ServiceManagerUpdated(address indexed newServiceManager);

    bytes32 private constant _LOAN_LIMIT_ORDER_TYPEHASH = keccak256(
        "LoanLimitOrder(address lender,address token,uint256 principalAmount,uint256 collateralRequired,uint32 interestRateBips,uint64 maturityTimestamp,uint64 expiry,uint256 nonce)"
    );

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

    constructor(address _debtHookAddress, address _usdcAddress) {
        debtHook = IDebtHook(_debtHookAddress);
        usdc = ERC20(_usdcAddress);
    }

    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        name = "DebtOrderBook";
        version = "1";
    }

    function fillLimitOrder(LoanLimitOrder calldata order, bytes calldata signature) external payable {
        require(block.timestamp < order.expiry, "DebtOrderBook: Order expired");
        require(msg.value >= order.collateralRequired, "DebtOrderBook: Insufficient collateral");

        bytes32 orderHash = _hashLoanLimitOrder(order);
        address recoveredLender = ECDSA.recover(orderHash, signature);

        require(recoveredLender == order.lender && recoveredLender != address(0), "DebtOrderBook: Invalid signature");

        require(!usedNonces[order.nonce], "DebtOrderBook: Nonce already used");
        usedNonces[order.nonce] = true;

        usdc.transferFrom(order.lender, address(this), order.principalAmount);
        usdc.approve(address(debtHook), order.principalAmount);

        debtHook.createLoan{value: msg.value}(
            IDebtHook.CreateLoanParams({
                lender: order.lender,
                borrower: msg.sender,
                principalAmount: order.principalAmount,
                collateralAmount: msg.value,
                maturityTimestamp: order.maturityTimestamp,
                interestRateBips: order.interestRateBips
            })
        );

        emit OrderFilled(orderHash, msg.sender, order.principalAmount);
    }

    // ... (Otras funciones como cancelOrder) ...

    function hashLoanLimitOrder(LoanLimitOrder calldata order) public view returns (bytes32) {
        return _hashLoanLimitOrder(order);
    }

    function _hashLoanLimitOrder(LoanLimitOrder calldata order) internal view returns (bytes32) {
        return _hashTypedData(
            keccak256(
                abi.encode(
                    _LOAN_LIMIT_ORDER_TYPEHASH,
                    order.lender,
                    order.token,
                    order.principalAmount,
                    order.collateralRequired,
                    order.interestRateBips,
                    order.maturityTimestamp,
                    order.expiry,
                    order.nonce
                )
            )
        );
    }

    // --- EigenLayer Integration Functions ---

    /**
     * @notice Submit a signed loan order to the EigenLayer AVS for matching
     * @param order The loan order to submit
     * @param signature The lender's signature
     * @param minPrincipal Minimum principal amount willing to lend
     * @param maxPrincipal Maximum principal amount willing to lend
     * @param minRate Minimum acceptable interest rate
     * @param maxRate Maximum acceptable interest rate
     */
    function submitOrderToAVS(
        LoanLimitOrder calldata order,
        bytes calldata signature,
        uint256 minPrincipal,
        uint256 maxPrincipal,
        uint256 minRate,
        uint256 maxRate
    ) external {
        require(serviceManager != address(0), "DebtOrderBook: ServiceManager not set");
        require(block.timestamp < order.expiry, "DebtOrderBook: Order expired");
        
        // Verify signature
        bytes32 orderHash = _hashLoanLimitOrder(order);
        address recoveredLender = ECDSA.recover(orderHash, signature);
        require(recoveredLender == order.lender && recoveredLender != address(0), "DebtOrderBook: Invalid signature");
        
        // Check if submitter is the lender
        require(msg.sender == order.lender, "DebtOrderBook: Only lender can submit order");
        
        // Forward to ServiceManager
        IDebtOrderServiceManager(serviceManager).createLoanOrder(
            true, // isLender
            order.principalAmount,
            order.interestRateBips,
            order.maturityTimestamp,
            order.collateralRequired,
            order.lender,
            minPrincipal,
            maxPrincipal,
            minRate,
            maxRate,
            order.expiry
        );
        
        emit OrderSubmittedToAVS(orderHash, order.lender);
    }

    /**
     * @notice Submit a borrower order to the EigenLayer AVS for matching
     * @param principalAmount Amount to borrow
     * @param maxInterestRateBips Maximum interest rate willing to pay
     * @param maturityTimestamp Loan maturity
     * @param collateralAmount ETH collateral amount
     * @param minPrincipal Minimum amount willing to borrow
     * @param maxPrincipal Maximum amount willing to borrow
     * @param expiry Order expiration timestamp
     */
    function submitBorrowerOrderToAVS(
        uint256 principalAmount,
        uint256 maxInterestRateBips,
        uint256 maturityTimestamp,
        uint256 collateralAmount,
        uint256 minPrincipal,
        uint256 maxPrincipal,
        uint256 expiry
    ) external {
        require(serviceManager != address(0), "DebtOrderBook: ServiceManager not set");
        require(expiry > block.timestamp, "DebtOrderBook: Order expired");
        require(maturityTimestamp > block.timestamp, "DebtOrderBook: Invalid maturity");
        
        // Forward to ServiceManager
        IDebtOrderServiceManager(serviceManager).createLoanOrder(
            false, // isLender = false for borrower
            principalAmount,
            maxInterestRateBips,
            maturityTimestamp,
            collateralAmount,
            msg.sender,
            minPrincipal,
            maxPrincipal,
            0, // minRate (not used for borrowers)
            maxInterestRateBips, // maxRate
            expiry
        );
    }

    /**
     * @notice Update the ServiceManager address (only owner/admin)
     * @param _serviceManager New ServiceManager address
     */
    function setServiceManager(address _serviceManager) external {
        // TODO: Add access control (onlyOwner or similar)
        require(_serviceManager != address(0), "DebtOrderBook: Invalid address");
        serviceManager = _serviceManager;
        emit ServiceManagerUpdated(_serviceManager);
    }
}

// Interface for DebtOrderServiceManager
interface IDebtOrderServiceManager {
    function createLoanOrder(
        bool isLender,
        uint256 principalAmount,
        uint256 interestRateBips,
        uint256 maturityTimestamp,
        uint256 collateralRequired,
        address sender,
        uint256 minPrincipal,
        uint256 maxPrincipal,
        uint256 minRate,
        uint256 maxRate,
        uint256 expiry
    ) external;
}
