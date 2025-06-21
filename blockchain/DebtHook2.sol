// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {IUnlockCallback} from "v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {IDebtHook} from "./interfaces/IDebtHook.sol";
import {IERC20} from "solady/interfaces/IERC20.sol";
import {PRBMathUD60x18, PRBMath} from "prb-math/PRBMath.sol";

contract DebtHook is BaseHook, IUnlockCallback, IDebtHook {
    using CurrencyLibrary for Currency;

    // --- State & Config ---
    address public immutable debtOrderBook;
    address public immutable treasury;
    Currency public immutable currency0; // ETH (address(0))
    Currency public immutable currency1; // USDC
    uint24 public immutable fee;
    int24 public immutable tickSpacing;

    uint64 public constant GRACE_PERIOD = 24 hours;
    uint256 public constant PENALTY_BIPS = 500; // 5%

    enum LoanStatus {
        Active,
        Repaid,
        Liquidated
    }

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

    mapping(bytes32 => Loan) public loans;
    uint256 private loanCounter;

    // --- Events ---
    event LoanCreated(
        bytes32 indexed loanId,
        address indexed lender,
        address indexed borrower
    );
    event LoanRepaid(bytes32 indexed loanId);
    event LoanLiquidated(
        bytes32 indexed loanId,
        uint256 proceeds,
        uint256 surplus
    );

    // --- Modifiers ---
    modifier onlyOrderBook() {
        require(
            msg.sender == debtOrderBook,
            "DebtHook: Caller is not the order book"
        );
        _;
    }

    // --- Constructor ---
    constructor(
        IPoolManager _poolManager,
        address _debtOrderBook,
        address _treasury,
        Currency _currency0,
        Currency _currency1,
        uint24 _fee,
        int24 _tickSpacing
    ) BaseHook(_poolManager) {
        debtOrderBook = _debtOrderBook;
        treasury = _treasury;
        currency0 = _currency0;
        currency1 = _currency1;
        fee = _fee;
        tickSpacing = _tickSpacing;
    }

    // --- Hook Permissions ---
    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                afterAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: false,
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    // --- Loan Lifecycle ---
    function createLoan(
        CreateLoanParams calldata params
    ) external payable override onlyOrderBook returns (bytes32 loanId) {
        loanCounter++;
        loanId = keccak256(
            abi.encodePacked(loanCounter, block.timestamp, params.borrower)
        );

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

        IERC20(currency1.toAddress()).transferFrom(
            msg.sender,
            params.borrower,
            params.principalAmount
        );

        emit LoanCreated(loanId, params.lender, params.borrower);
    }

    function repayLoan(bytes32 loanId) external {
        Loan storage loan = loans[loanId];
        require(msg.sender == loan.borrower, "DebtHook: Not the borrower");
        require(loan.status == LoanStatus.Active, "DebtHook: Loan not active");
        require(
            block.timestamp >= loan.maturityTimestamp,
            "DebtHook: Loan not mature"
        );

        uint256 totalDebt = _calculateCurrentDebt(loan);

        IERC20(currency1.toAddress()).transferFrom(
            msg.sender,
            loan.lender,
            totalDebt
        );

        (bool sent, ) = loan.borrower.call{value: loan.collateralAmount}("");
        require(sent, "DebtHook: Failed to return collateral");

        loan.status = LoanStatus.Repaid;
        emit LoanRepaid(loanId);
    }

    function liquidate(bytes32 loanId) external {
        Loan storage loan = loans[loanId];
        require(msg.sender == loan.lender, "DebtHook: Not the lender");
        require(loan.status == LoanStatus.Active, "DebtHook: Loan not active");

        bool isDefaulted = block.timestamp >
            loan.maturityTimestamp + GRACE_PERIOD;
        require(isDefaulted, "DebtHook: Resolution condition not met");

        bytes memory unlockData = abi.encode(loanId);
        poolManager.unlock(unlockData);
    }

    // --- Uniswap v4 Unlock Callback ---
    function unlockCallback(
        bytes calldata data
    ) external override returns (bytes memory) {
        require(
            msg.sender == address(poolManager),
            "DebtHook: Not the pool manager"
        );
        bytes32 loanId = abi.decode(data, (bytes32));
        Loan storage loan = loans[loanId];

        PoolKey memory key = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(address(this))
        });

        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: true,
            amountSpecified: int256(loan.collateralAmount),
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });

        BalanceDelta swapDelta = poolManager.swap(key, params, new bytes(0));

        int128 usdcProceeds = swapDelta.amount1();
        require(usdcProceeds > 0, "DebtHook: Liquidation yielded no proceeds");

        poolManager.settle(currency1);

        _distributeProceeds(loan, uint256(usdcProceeds));

        loan.status = LoanStatus.Liquidated;
        emit LoanLiquidated(loanId, uint256(usdcProceeds), 0);
        return new bytes(0);
    }

    // --- Internal Helpers ---
    function _distributeProceeds(Loan storage loan, uint256 proceeds) internal {
        uint256 debt = _calculateCurrentDebt(loan);
        uint256 amountToLender = proceeds > debt ? debt : proceeds;

        IERC20(currency1.toAddress()).transfer(loan.lender, amountToLender);

        if (proceeds > amountToLender) {
            uint256 surplus = proceeds - amountToLender;
            uint256 finalSurplusToBorrower = surplus;

            bool isDefaulted = block.timestamp >
                loan.maturityTimestamp + GRACE_PERIOD;
            if (isDefaulted) {
                uint256 penalty = (surplus * PENALTY_BIPS) / 10000;
                if (penalty > 0) {
                    IERC20(currency1.toAddress()).transfer(treasury, penalty);
                    finalSurplusToBorrower -= penalty;
                }
            }

            if (finalSurplusToBorrower > 0) {
                IERC20(currency1.toAddress()).transfer(
                    loan.borrower,
                    finalSurplusToBorrower
                );
            }
        }
    }

    function _calculateCurrentDebt(
        Loan memory loan
    ) internal view returns (uint256) {
        uint256 elapsedTime = block.timestamp < loan.maturityTimestamp
            ? block.timestamp - loan.creationTimestamp
            : loan.maturityTimestamp - loan.creationTimestamp;

        // Tasa anual (r) como un número de punto fijo UD60x18
        int256 r_annual = int256(
            (uint256(loan.interestRateBips) * 1e18) / 10000
        );

        // (r * t) / (segundos en un año) para normalizar la tasa
        int256 rt_normalized = PRBMath.mul(r_annual, int256(elapsedTime)) /
            int256(365 days);

        // e^(rt)
        uint256 growthFactor = PRBMath.exp(rt_normalized);

        // Deuda Total = Principal * e^(rt)
        // Se necesita escalar el principal a la misma precisión que el `growthFactor` (1e18)
        return PRBMath.mul(loan.principalAmount * 1e12, growthFactor) / 1e12; // Ajustar precisión de USDC (6 decimales)
    }
}
