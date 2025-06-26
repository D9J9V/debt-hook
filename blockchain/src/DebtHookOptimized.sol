// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {IUnlockCallback} from "v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {IPriceFeed} from "./interfaces/IPriceFeed.sol";
import {IDebtHook} from "./interfaces/IDebtHook.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {SwapParams} from "v4-core/src/types/PoolOperation.sol";

/// @title DebtHook Optimized
/// @notice Streamlined version of DebtHook to fit within contract size limits
contract DebtHookOptimized is BaseHook, IUnlockCallback, IDebtHook {
    using CurrencyLibrary for Currency;

    IPriceFeed public immutable priceFeed;
    address public immutable debtOrderBook;
    address public immutable treasury;
    Currency public immutable currency0;
    Currency public immutable currency1;
    uint24 public immutable fee;
    int24 public immutable tickSpacing;

    uint64 public constant GRACE_PERIOD = 24 hours;
    uint256 public constant PENALTY_BIPS = 500;

    struct Loan {
        bytes32 id;
        address lender;
        address borrower;
        uint256 principalAmount;
        uint256 collateralAmount;
        uint64 creationTimestamp;
        uint64 maturityTimestamp;
        uint32 interestRateBips;
        LoanStatus status;
    }

    enum LoanStatus {
        Active,
        Repaid,
        Liquidated
    }

    mapping(address => bool) public authorizedOperators;
    mapping(address => uint256[]) public borrowerLoans;
    mapping(address => uint256[]) public lenderLoans;
    mapping(bytes32 => Loan) public loans;
    mapping(uint256 => bytes32) public loanIdMapping;
    uint256 private loanCounter;

    // Transient storage slots
    uint256 constant LIQUIDATION_LOAN_ID = 0x100;
    uint256 constant LIQUIDATION_COLLATERAL_AMOUNT = 0x101;
    uint256 constant LIQUIDATION_DEBT_AMOUNT = 0x102;

    event LoanCreated(bytes32 indexed loanId, address indexed lender, address indexed borrower);
    event LoanRepaid(bytes32 indexed loanId);
    event LoanLiquidated(bytes32 indexed loanId, uint256 proceeds, uint256 surplus);
    event OperatorAuthorized(address indexed operator, bool authorized);

    modifier onlyOrderBook() {
        require(msg.sender == debtOrderBook, "Not order book");
        _;
    }

    constructor(
        IPoolManager _poolManager,
        address _priceFeedAddress,
        address _debtOrderBook,
        address _treasury,
        Currency _currency0,
        Currency _currency1,
        uint24 _fee,
        int24 _tickSpacing
    ) BaseHook(_poolManager) {
        priceFeed = IPriceFeed(_priceFeedAddress);
        debtOrderBook = _debtOrderBook;
        treasury = _treasury;
        currency0 = _currency0;
        currency1 = _currency1;
        fee = _fee;
        tickSpacing = _tickSpacing;
    }

    function authorizeOperator(address operator, bool authorized) external {
        require(msg.sender == treasury, "Only treasury");
        authorizedOperators[operator] = authorized;
        emit OperatorAuthorized(operator, authorized);
    }

    function createLoan(CreateLoanParams calldata params)
        external
        payable
        override
        onlyOrderBook
        returns (bytes32 loanId)
    {
        require(params.collateralAmount > 0 && params.principalAmount > 0, "Invalid amounts");
        require(params.maturityTimestamp > block.timestamp, "Invalid maturity");

        loanCounter++;
        loanId = keccak256(abi.encodePacked(loanCounter, block.timestamp, params.borrower));
        loanIdMapping[loanCounter] = loanId;

        loans[loanId] = Loan({
            id: loanId,
            lender: params.lender,
            borrower: params.borrower,
            principalAmount: params.principalAmount,
            collateralAmount: params.collateralAmount,
            creationTimestamp: uint64(block.timestamp),
            maturityTimestamp: params.maturityTimestamp,
            interestRateBips: params.interestRateBips,
            status: LoanStatus.Active
        });

        borrowerLoans[params.borrower].push(loanCounter);
        lenderLoans[params.lender].push(loanCounter);

        ERC20(Currency.unwrap(currency1)).transferFrom(msg.sender, params.borrower, params.principalAmount);
        emit LoanCreated(loanId, params.lender, params.borrower);
    }

    function createBatchLoans(
        LoanMatch[] calldata matches,
        bytes calldata
    ) external override returns (bytes32[] memory loanIds) {
        require(authorizedOperators[msg.sender], "Not authorized");
        
        loanIds = new bytes32[](matches.length);
        
        for (uint256 i = 0; i < matches.length; i++) {
            LoanMatch calldata loanMatch = matches[i];
            
            loanCounter++;
            bytes32 loanId = keccak256(abi.encodePacked(loanCounter, block.timestamp, loanMatch.borrower));
            loanIdMapping[loanCounter] = loanId;
            
            loans[loanId] = Loan({
                id: loanId,
                lender: loanMatch.lender,
                borrower: loanMatch.borrower,
                principalAmount: loanMatch.principalAmount,
                collateralAmount: 0,
                creationTimestamp: uint64(block.timestamp),
                maturityTimestamp: uint64(loanMatch.maturityTimestamp),
                interestRateBips: uint32(loanMatch.interestRateBips),
                status: LoanStatus.Active
            });
            
            borrowerLoans[loanMatch.borrower].push(loanCounter);
            lenderLoans[loanMatch.lender].push(loanCounter);
            
            ERC20(Currency.unwrap(currency1)).transferFrom(
                loanMatch.lender,
                loanMatch.borrower,
                loanMatch.principalAmount
            );
            
            loanIds[i] = loanId;
            emit LoanCreated(loanId, loanMatch.lender, loanMatch.borrower);
        }
    }

    function repayLoan(bytes32 loanId) external {
        Loan storage loan = loans[loanId];
        require(loan.id != bytes32(0), "Loan not found");
        require(msg.sender == loan.borrower, "Not borrower");
        require(loan.status == LoanStatus.Active, "Not active");

        uint256 totalDebt = _calculateDebt(loan.principalAmount, loan.interestRateBips, 
            block.timestamp - loan.creationTimestamp, loan.maturityTimestamp - loan.creationTimestamp);

        ERC20(Currency.unwrap(currency1)).transferFrom(msg.sender, loan.lender, totalDebt);
        
        (bool sent,) = loan.borrower.call{value: loan.collateralAmount}("");
        require(sent, "ETH transfer failed");

        loan.status = LoanStatus.Repaid;
        emit LoanRepaid(loanId);
    }

    function liquidate(bytes32 loanId) external {
        Loan storage loan = loans[loanId];
        require(msg.sender == loan.lender, "Not lender");
        require(loan.status == LoanStatus.Active, "Not active");

        bool isDefaulted = block.timestamp > loan.maturityTimestamp + GRACE_PERIOD;
        uint256 currentDebt = _calculateDebt(loan.principalAmount, loan.interestRateBips,
            block.timestamp - loan.creationTimestamp, loan.maturityTimestamp - loan.creationTimestamp);
        uint256 collateralValue = _getCollateralValue(loan.collateralAmount);
        
        require(isDefaulted || collateralValue < currentDebt, "Not liquidatable");

        bytes memory unlockData = abi.encode(loanId);
        poolManager.unlock(unlockData);
    }

    function unlockCallback(bytes calldata data) external override returns (bytes memory) {
        require(msg.sender == address(poolManager), "Not pool manager");

        bytes32 loanId = abi.decode(data, (bytes32));
        Loan storage loan = loans[loanId];

        PoolKey memory key = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(address(this))
        });

        SwapParams memory params = SwapParams({
            zeroForOne: true,
            amountSpecified: int256(loan.collateralAmount),
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });

        BalanceDelta swapDelta = poolManager.swap(key, params, new bytes(0));
        
        uint256 proceeds = uint256(uint128(swapDelta.amount1()));
        _distributeProceeds(loan, proceeds);
        
        loan.status = LoanStatus.Liquidated;
        emit LoanLiquidated(loanId, proceeds, 0);

        return new bytes(0);
    }

    function _calculateDebt(uint256 principal, uint32 rateBips, uint256 elapsed, uint256 totalDuration) 
        internal pure returns (uint256) {
        if (elapsed > totalDuration) elapsed = totalDuration;
        uint256 interest = (principal * rateBips * elapsed) / (10000 * 365 days);
        return principal + interest;
    }

    function _getCollateralValue(uint256 collateralAmount) internal view returns (uint256) {
        (, int256 ethPriceUSD,,,) = priceFeed.latestRoundData();
        require(ethPriceUSD > 0, "Invalid price");
        uint8 decimals = priceFeed.decimals();
        return (collateralAmount * uint256(ethPriceUSD)) / 10 ** (18 + decimals - 6);
    }

    function _distributeProceeds(Loan storage loan, uint256 proceeds) internal {
        uint256 debt = _calculateDebt(loan.principalAmount, loan.interestRateBips,
            block.timestamp - loan.creationTimestamp, loan.maturityTimestamp - loan.creationTimestamp);
        
        uint256 toLender = proceeds > debt ? debt : proceeds;
        ERC20(Currency.unwrap(currency1)).transfer(loan.lender, toLender);
        
        if (proceeds > toLender) {
            uint256 surplus = proceeds - toLender;
            uint256 penalty = (surplus * PENALTY_BIPS) / 10000;
            if (penalty > 0) {
                ERC20(Currency.unwrap(currency1)).transfer(treasury, penalty);
                surplus -= penalty;
            }
            if (surplus > 0) {
                ERC20(Currency.unwrap(currency1)).transfer(loan.borrower, surplus);
            }
        }
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: true,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function _beforeSwap(address, PoolKey calldata, SwapParams calldata, bytes calldata)
        internal
        pure
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        // Simplified - no automatic liquidations in optimized version
        return (IHooks.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    function _afterSwap(address, PoolKey calldata, SwapParams calldata, BalanceDelta, bytes calldata)
        internal
        pure
        override
        returns (bytes4, int128)
    {
        return (IHooks.afterSwap.selector, 0);
    }

    // View functions
    function getLoan(uint256 loanIdNum) public view returns (Loan memory) {
        return loans[loanIdMapping[loanIdNum]];
    }

    function getBorrowerLoans(address borrower) public view returns (uint256[] memory) {
        return borrowerLoans[borrower];
    }

    function getLenderLoans(address lender) public view returns (uint256[] memory) {
        return lenderLoans[lender];
    }

    function calculateRepaymentAmount(Loan memory loan) public view returns (uint256) {
        return _calculateDebt(loan.principalAmount, loan.interestRateBips,
            block.timestamp - loan.creationTimestamp, loan.maturityTimestamp - loan.creationTimestamp);
    }

    function repayLoan(uint256 loanIdNum) external {
        bytes32 loanId = loanIdMapping[loanIdNum];
        Loan storage loan = loans[loanId];
        require(loan.id != bytes32(0), "Loan not found");
        require(msg.sender == loan.borrower, "Not borrower");
        require(loan.status == LoanStatus.Active, "Not active");

        uint256 totalDebt = _calculateDebt(loan.principalAmount, loan.interestRateBips, 
            block.timestamp - loan.creationTimestamp, loan.maturityTimestamp - loan.creationTimestamp);

        ERC20(Currency.unwrap(currency1)).transferFrom(msg.sender, loan.lender, totalDebt);
        
        (bool sent,) = loan.borrower.call{value: loan.collateralAmount}("");
        require(sent, "ETH transfer failed");

        loan.status = LoanStatus.Repaid;
        emit LoanRepaid(loanId);
    }

    function depositCollateral(bytes32 loanId) external payable {
        Loan storage loan = loans[loanId];
        require(loan.id != bytes32(0), "Loan not found");
        require(msg.sender == loan.borrower, "Not borrower");
        require(loan.collateralAmount == 0, "Already deposited");
        require(msg.value > 0, "No collateral");
        
        (, int256 ethPrice,,,) = priceFeed.latestRoundData();
        require(ethPrice > 0, "Invalid price");
        
        uint256 requiredValue = (loan.principalAmount * 150) / 100;
        uint256 requiredCollateral = (requiredValue * 10 ** (18 + priceFeed.decimals())) / 
                                     (uint256(ethPrice) * 10 ** 6);
        
        require(msg.value >= requiredCollateral, "Insufficient collateral");
        loan.collateralAmount = msg.value;
    }
}