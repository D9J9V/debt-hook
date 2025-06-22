// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IUnlockCallback} from "v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {SwapParams} from "v4-core/src/types/PoolOperation.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {IPriceFeed} from "./interfaces/IPriceFeed.sol";
import {IDebtProtocol} from "./interfaces/IDebtProtocol.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {UD60x18, ud} from "prb-math/UD60x18.sol";
import {mul, exp} from "prb-math/ud60x18/Math.sol";

/// @title DebtProtocol
/// @notice Main lending protocol that manages collateralized debt positions
/// @dev Uses Uniswap v4 PoolManager for liquidations but is not a hook itself
contract DebtProtocol is IUnlockCallback, IDebtProtocol {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    // --- State Variables ---

    /// @notice Uniswap v4 PoolManager for liquidation swaps
    IPoolManager public immutable poolManager;
    
    /// @notice Price oracle for collateral valuation (e.g., ETH/USD)
    IPriceFeed public immutable priceFeed;
    
    /// @notice Address of the order book contract
    address public immutable debtOrderBook;
    
    /// @notice Treasury address for penalty collection
    address public immutable treasury;
    
    /// @notice Pool currencies
    Currency public immutable currency0; // ETH (address(0))
    Currency public immutable currency1; // USDC
    
    /// @notice Pool parameters for liquidation
    uint24 public immutable fee;
    int24 public immutable tickSpacing;
    
    /// @notice Liquidation constants
    uint64 public constant GRACE_PERIOD = 24 hours;
    uint256 public constant PENALTY_BIPS = 500; // 5%

    /// @notice Storage for all loans
    mapping(uint256 => Loan) public loans;
    
    /// @notice Temporary storage for liquidation data
    mapping(address => LiquidationData) private liquidationData;
    
    /// @notice Track loans by borrower
    mapping(address => uint256[]) public borrowerLoans;
    
    /// @notice Track loans by lender
    mapping(address => uint256[]) public lenderLoans;
    
    /// @notice Next loan ID
    uint256 public nextLoanId = 1;

    // --- Events ---

    event LoanCreated(
        uint256 indexed loanId,
        address indexed borrower,
        address indexed lender,
        uint256 principal,
        uint256 collateralAmount,
        uint64 startTime,
        uint64 duration,
        uint64 interestRate
    );

    event LoanRepaid(
        uint256 indexed loanId,
        address indexed borrower,
        uint256 principalPaid,
        uint256 interestPaid,
        uint256 collateralReturned
    );

    event LoanLiquidated(
        uint256 indexed loanId,
        address indexed liquidator,
        uint256 collateralSold,
        uint256 usdcReceived,
        uint256 penaltyAmount,
        uint256 borrowerRefund
    );

    // --- Errors ---

    error Unauthorized();
    error InvalidAmount();
    error InsufficientCollateral();
    error LoanNotFound();
    error LoanNotLiquidatable();
    error LoanAlreadyRepaid();
    error RepaymentTooLate();
    error TransferFailed();
    error InvalidPriceFeed();
    error InvalidOrderBook();

    // --- Modifiers ---

    modifier onlyOrderBook() {
        if (msg.sender != debtOrderBook) revert Unauthorized();
        _;
    }

    // --- Constructor ---

    constructor(
        IPoolManager _poolManager,
        Currency _currency0,
        Currency _currency1,
        uint24 _fee,
        int24 _tickSpacing,
        IPriceFeed _priceFeed,
        address _treasury,
        address _debtOrderBook
    ) {
        if (address(_priceFeed) == address(0)) revert InvalidPriceFeed();
        if (_debtOrderBook == address(0)) revert InvalidOrderBook();
        
        poolManager = _poolManager;
        currency0 = _currency0;
        currency1 = _currency1;
        fee = _fee;
        tickSpacing = _tickSpacing;
        priceFeed = _priceFeed;
        treasury = _treasury;
        debtOrderBook = _debtOrderBook;
    }

    // --- Core Functions ---

    function createLoan(LoanParams calldata params) external payable onlyOrderBook returns (uint256 loanId) {
        if (params.principal == 0) revert InvalidAmount();
        if (msg.value == 0) revert InvalidAmount();

        // Calculate required collateral based on current price
        uint256 ethPrice = getEthPrice();
        uint256 requiredCollateralValue = (params.principal * 15000) / 10000; // 150% collateralization
        uint256 requiredCollateral = (requiredCollateralValue * 1e18) / ethPrice;

        if (msg.value < requiredCollateral) revert InsufficientCollateral();

        // Create loan
        loanId = nextLoanId++;
        loans[loanId] = Loan({
            borrower: params.borrower,
            lender: params.lender,
            principal: params.principal,
            collateralAmount: msg.value,
            startTime: uint64(block.timestamp),
            duration: params.duration,
            interestRate: params.interestRate,
            isRepaid: false,
            isLiquidated: false
        });

        // Track loan for both parties
        borrowerLoans[params.borrower].push(loanId);
        lenderLoans[params.lender].push(loanId);

        // Transfer USDC from orderBook (msg.sender) to borrower
        // The orderBook should have already received the USDC from the lender
        ERC20(Currency.unwrap(currency1)).transferFrom(msg.sender, params.borrower, params.principal);

        emit LoanCreated(
            loanId,
            params.borrower,
            params.lender,
            params.principal,
            msg.value,
            uint64(block.timestamp),
            params.duration,
            params.interestRate
        );
    }

    function repayLoan(uint256 loanId) external {
        Loan storage loan = loans[loanId];
        
        if (loan.borrower == address(0)) revert LoanNotFound();
        if (loan.isRepaid || loan.isLiquidated) revert LoanAlreadyRepaid();
        if (msg.sender != loan.borrower) revert Unauthorized();

        uint64 endTime = loan.startTime + loan.duration;
        if (block.timestamp > endTime + GRACE_PERIOD) revert RepaymentTooLate();

        // Calculate repayment amount with interest
        uint256 repaymentAmount = calculateRepaymentAmount(loan);

        // Mark loan as repaid
        loan.isRepaid = true;

        // Transfer USDC from borrower to lender
        ERC20(Currency.unwrap(currency1)).transferFrom(msg.sender, loan.lender, repaymentAmount);

        // Return collateral to borrower
        (bool success,) = payable(loan.borrower).call{value: loan.collateralAmount}("");
        if (!success) revert TransferFailed();

        emit LoanRepaid(
            loanId,
            loan.borrower,
            loan.principal,
            repaymentAmount - loan.principal,
            loan.collateralAmount
        );
    }

    function liquidateLoan(uint256 loanId) external {
        Loan storage loan = loans[loanId];
        
        if (loan.borrower == address(0)) revert LoanNotFound();
        if (loan.isRepaid || loan.isLiquidated) revert LoanAlreadyRepaid();

        // Check if loan is liquidatable
        if (!isLiquidatable(loan)) revert LoanNotLiquidatable();

        // Mark as liquidated
        loan.isLiquidated = true;

        // Store liquidation data
        liquidationData[msg.sender] = LiquidationData({
            liquidator: msg.sender,
            loanId: loanId,
            collateralAmount: loan.collateralAmount,
            debtAmount: calculateRepaymentAmount(loan),
            lender: loan.lender,
            borrower: loan.borrower,
            isActive: true
        });

        // Execute swap through PoolManager
        poolManager.unlock(abi.encode(msg.sender));
    }

    function unlockCallback(bytes calldata data) external override returns (bytes memory) {
        if (msg.sender != address(poolManager)) revert Unauthorized();

        address liquidator = abi.decode(data, (address));
        LiquidationData memory liquidation = liquidationData[liquidator];
        
        if (!liquidation.isActive) revert Unauthorized();

        // Prepare swap parameters
        PoolKey memory key = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(address(0)) // No hooks for this pool
        });

        SwapParams memory params = SwapParams({
            zeroForOne: true, // Swap ETH (currency0) for USDC (currency1)
            amountSpecified: -int256(liquidation.collateralAmount),
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });

        // Execute swap
        BalanceDelta delta = poolManager.swap(key, params, "");

        // Calculate amounts from delta
        uint256 usdcReceived = uint256(int256(delta.amount1()));
        
        // Calculate penalty
        uint256 penalty = (liquidation.debtAmount * PENALTY_BIPS) / 10000;
        uint256 totalDebt = liquidation.debtAmount + penalty;

        // Distribute funds
        if (usdcReceived >= totalDebt) {
            // Pay lender
            poolManager.take(currency1, liquidation.lender, liquidation.debtAmount);
            
            // Pay penalty to treasury
            poolManager.take(currency1, treasury, penalty);
            
            // Return surplus to borrower
            uint256 surplus = usdcReceived - totalDebt;
            if (surplus > 0) {
                poolManager.take(currency1, liquidation.borrower, surplus);
            }
        } else {
            // Partial recovery - give all to lender
            poolManager.take(currency1, liquidation.lender, usdcReceived);
        }

        // Clean up
        delete liquidationData[liquidator];

        emit LoanLiquidated(
            liquidation.loanId,
            liquidator,
            liquidation.collateralAmount,
            usdcReceived,
            penalty,
            usdcReceived > totalDebt ? usdcReceived - totalDebt : 0
        );

        return "";
    }

    // --- View Functions ---

    function calculateRepaymentAmount(Loan memory loan) public view returns (uint256) {
        // Calculate continuous compound interest
        UD60x18 principal = ud(loan.principal);
        UD60x18 rate = ud(uint256(loan.interestRate) * 1e18 / 10000 / 365 days);
        UD60x18 time = ud(uint256(block.timestamp - loan.startTime) * 1e18);
        UD60x18 exponent = mul(rate, time);
        UD60x18 multiplier = exp(exponent);
        UD60x18 amount = mul(principal, multiplier);
        
        return amount.intoUint256();
    }

    function isLiquidatable(Loan memory loan) public view returns (bool) {
        if (loan.isRepaid || loan.isLiquidated) return false;
        
        // Check if grace period has passed
        uint64 endTime = loan.startTime + loan.duration;
        if (block.timestamp > endTime + GRACE_PERIOD) return true;
        
        // Check if collateral value dropped below threshold
        uint256 ethPrice = getEthPrice();
        uint256 collateralValue = (loan.collateralAmount * ethPrice) / 1e18;
        uint256 debtValue = calculateRepaymentAmount(loan);
        uint256 minCollateralValue = (debtValue * 15000) / 10000; // 150% threshold
        
        return collateralValue < minCollateralValue;
    }

    function getEthPrice() public view returns (uint256) {
        if (address(priceFeed) == address(0)) {
            // Mock price for testing
            return 2000e8; // $2000 with 8 decimals
        }
        
        (, int256 price,,,) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price");
        
        // Convert to 18 decimals
        return uint256(price) * 1e10;
    }

    function getLoan(uint256 loanId) external view returns (Loan memory) {
        return loans[loanId];
    }

    function getBorrowerLoans(address borrower) external view returns (uint256[] memory) {
        return borrowerLoans[borrower];
    }

    function getLenderLoans(address lender) external view returns (uint256[] memory) {
        return lenderLoans[lender];
    }
}