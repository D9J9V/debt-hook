// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {IUnlockCallback} from "v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {IPriceFeed} from "./interfaces/IPriceFeed.sol"; // Interfaz para Chainlink
import {IDebtHook} from "./interfaces/IDebtHook.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {UD60x18, ud} from "prb-math/UD60x18.sol";
import {mul, exp} from "prb-math/ud60x18/Math.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {SwapParams} from "v4-core/src/types/PoolOperation.sol";

// DebtHook es un contrato que gestiona posiciones de deuda colateralizada.
// Utiliza un pool de Uniswap v4 como capa de liquidación.
// Implementa hooks de Uniswap v4 para manejar liquidaciones a través de swaps.
contract DebtHook is BaseHook, IUnlockCallback, IDebtHook {
    using CurrencyLibrary for Currency;
    // --- State Variables ---

    // Oráculo de precios para obtener el valor del colateral (ej. ETH/USD)
    IPriceFeed public immutable priceFeed;
    
    // Dirección del order book para control de acceso
    address public immutable debtOrderBook;
    
    // Dirección del treasury para cobrar penalizaciones
    address public immutable treasury;
    
    // Monedas del pool (ETH y USDC)
    Currency public immutable currency0; // ETH (address(0))
    Currency public immutable currency1; // USDC
    
    // Parámetros del pool de liquidación
    uint24 public immutable fee;
    int24 public immutable tickSpacing;
    
    // Constantes de liquidación
    uint64 public constant GRACE_PERIOD = 24 hours;
    uint256 public constant PENALTY_BIPS = 500; // 5%
    
    // Custom errors
    error LoanNotFound();
    error LoanAlreadyRepaid();
    error LoanNotLiquidatable();

    // Storage mappings for loans
    mapping(address => uint256[]) public borrowerLoans;
    mapping(address => uint256[]) public lenderLoans;
    
    // Transient storage slots for liquidation data (using fixed slot numbers)
    uint256 constant LIQUIDATION_LOAN_ID = 0x100;
    uint256 constant LIQUIDATION_COLLATERAL_AMOUNT = 0x101;
    uint256 constant LIQUIDATION_DEBT_AMOUNT = 0x102;
    
    // Estructura para almacenar los detalles de cada préstamo
    struct Loan {
        bytes32 id;
        address lender;
        address borrower;
        uint256 principalAmount; // Cantidad de USDC prestada (6 decimales)
        uint256 collateralAmount; // Cantidad de ETH como colateral (18 decimales)
        uint64 creationTimestamp; // t_0: momento de creación del préstamo
        uint64 maturityTimestamp; // T: momento de vencimiento
        uint32 interestRateBips; // Tasa de interés anual en BIPS (ej. 1000 = 10%)
        LoanStatus status;
    }

    enum LoanStatus {
        Active,
        Repaid,
        Liquidated
    }

    // Mapping para almacenar todas las posiciones de préstamo
    mapping(bytes32 => Loan) public loans;
    mapping(uint256 => bytes32) public loanIdMapping; // Maps numeric ID to bytes32 ID
    uint256 private loanCounter; // Para generar IDs únicos

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

    // --- Core Logic: Loan Lifecycle Functions ---

    /**
     * @notice Crea una nueva posición de préstamo. Solo puede ser llamada por el DebtOrderBook.
     * @param params Parámetros del préstamo incluyendo lender, borrower, montos y términos.
     * @return loanId ID único del préstamo creado
     */
    function createLoan(
        CreateLoanParams calldata params
    ) external payable override onlyOrderBook returns (bytes32 loanId) {
        // Validaciones
        require(params.collateralAmount > 0, "DebtHook: Invalid collateral");
        require(params.principalAmount > 0, "DebtHook: Invalid principal");
        require(params.maturityTimestamp > block.timestamp, "DebtHook: Invalid maturity");
        
        // Generar ID único del préstamo
        loanCounter++;
        loanId = keccak256(
            abi.encodePacked(loanCounter, block.timestamp, params.borrower)
        );
        
        // Store mapping from numeric ID to bytes32 ID
        loanIdMapping[loanCounter] = loanId;

        // Crear y almacenar el préstamo
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

        // Track loan for borrower and lender
        borrowerLoans[params.borrower].push(loanCounter);
        lenderLoans[params.lender].push(loanCounter);
        
        // Transferir USDC del OrderBook (que ya tiene los fondos) al borrower
        ERC20(Currency.unwrap(currency1)).transferFrom(
            msg.sender,
            params.borrower,
            params.principalAmount
        );

        emit LoanCreated(loanId, params.lender, params.borrower);
    }

    /**
     * @notice Permite al prestatario repagar su deuda al vencimiento.
     * @param loanId El ID del préstamo a repagar.
     */
    function repayLoan(bytes32 loanId) external {
        _repayLoanInternal(loanId);
    }
    
    function _repayLoanInternal(bytes32 loanId) internal {
        Loan storage loan = loans[loanId];
        
        // Validaciones
        if (loan.id == bytes32(0)) revert LoanNotFound();
        require(msg.sender == loan.borrower, "DebtHook: Not the borrower");
        if (loan.status != LoanStatus.Active) revert LoanAlreadyRepaid();
        // Allow repayment at any time, not just at maturity

        // Calcular la deuda total con interés compuesto
        uint256 totalDebt = _calculateCurrentDebt(loan);

        // Transferir USDC del borrower al lender
        ERC20(Currency.unwrap(currency1)).transferFrom(
            msg.sender,
            loan.lender,
            totalDebt
        );

        // Devolver el colateral ETH al borrower
        (bool sent, ) = loan.borrower.call{value: loan.collateralAmount}("");
        require(sent, "DebtHook: Failed to return collateral");

        // Actualizar estado del préstamo
        loan.status = LoanStatus.Repaid;
        emit LoanRepaid(loanId);
    }

    /**
     * @notice Liquida un préstamo en default. Solo puede ser llamada por el lender después del periodo de gracia.
     * @param loanId El ID del préstamo a liquidar.
     */
    function liquidate(bytes32 loanId) external {
        Loan storage loan = loans[loanId];
        
        // Validaciones
        require(msg.sender == loan.lender, "DebtHook: Not the lender");
        require(loan.status == LoanStatus.Active, "DebtHook: Loan not active");

        // Verificar condición de liquidación: debe estar en default (después del periodo de gracia)
        bool isDefaulted = block.timestamp > loan.maturityTimestamp + GRACE_PERIOD;
        
        // También permitir liquidación si el colateral es insuficiente
        uint256 currentDebt = _calculateCurrentDebt(loan);
        uint256 collateralValue = _getCollateralValue(loan);
        bool isUnderwater = collateralValue < currentDebt;
        
        require(isDefaulted || isUnderwater, "DebtHook: Liquidation condition not met");

        // Iniciar proceso de liquidación a través del PoolManager
        bytes memory unlockData = abi.encode(loanId);
        poolManager.unlock(unlockData);
    }

    // --- Uniswap v4 Unlock Callback ---
    /**
     * @notice Callback ejecutado por el PoolManager durante la liquidación
     * @param data Datos codificados conteniendo el loanId
     * @return bytes empty bytes
     */
    function unlockCallback(
        bytes calldata data
    ) external override returns (bytes memory) {
        require(
            msg.sender == address(poolManager),
            "DebtHook: Not the pool manager"
        );
        
        bytes32 loanId = abi.decode(data, (bytes32));
        Loan storage loan = loans[loanId];

        // Configurar el pool key para el swap
        PoolKey memory key = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(address(this))
        });

        // Configurar parámetros del swap: vender todo el colateral ETH por USDC
        SwapParams memory params = SwapParams({
            zeroForOne: true, // ETH -> USDC
            amountSpecified: int256(loan.collateralAmount),
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
        });

        // Ejecutar el swap
        BalanceDelta swapDelta = poolManager.swap(key, params, new bytes(0));

        // Obtener los proceeds en USDC
        int128 usdcProceeds = swapDelta.amount1();
        require(usdcProceeds > 0, "DebtHook: Liquidation yielded no proceeds");

        // The swap already settled the balances, no need to call settle again

        // Distribuir los proceeds
        _distributeProceeds(loan, uint256(uint128(usdcProceeds)));

        // Actualizar estado del préstamo
        loan.status = LoanStatus.Liquidated;
        emit LoanLiquidated(loanId, uint256(uint128(usdcProceeds)), 0);
        
        return new bytes(0);
    }

    // --- Helper & View Functions ---

    /**
     * @notice Distribuye los proceeds de la liquidación entre lender, borrower y treasury
     * @param loan El préstamo siendo liquidado
     * @param proceeds Los USDC obtenidos de la venta del colateral
     */
    function _distributeProceeds(Loan storage loan, uint256 proceeds) internal {
        uint256 debt = _calculateCurrentDebt(loan);
        uint256 amountToLender = proceeds > debt ? debt : proceeds;

        // Pagar al lender hasta el monto de la deuda
        ERC20(Currency.unwrap(currency1)).transfer(loan.lender, amountToLender);

        // Si hay surplus, distribuirlo
        if (proceeds > amountToLender) {
            uint256 surplus = proceeds - amountToLender;
            uint256 finalSurplusToBorrower = surplus;

            // Si el préstamo está en default, cobrar penalización
            bool isDefaulted = block.timestamp > loan.maturityTimestamp + GRACE_PERIOD;
            if (isDefaulted) {
                uint256 penalty = (surplus * PENALTY_BIPS) / 10000;
                if (penalty > 0) {
                    ERC20(Currency.unwrap(currency1)).transfer(treasury, penalty);
                    finalSurplusToBorrower -= penalty;
                }
            }

            // Enviar el surplus restante al borrower
            if (finalSurplusToBorrower > 0) {
                ERC20(Currency.unwrap(currency1)).transfer(
                    loan.borrower,
                    finalSurplusToBorrower
                );
            }
        }
    }

    /**
     * @notice Calcula la deuda actual usando interés compuesto continuo
     * @param loan El préstamo para calcular la deuda
     * @return La deuda total actual en USDC
     */
    function _calculateCurrentDebt(
        Loan memory loan
    ) internal view returns (uint256) {
        // Calcular el tiempo transcurrido hasta la madurez o hasta ahora
        uint256 elapsedTime = block.timestamp < loan.maturityTimestamp
            ? block.timestamp - loan.creationTimestamp
            : loan.maturityTimestamp - loan.creationTimestamp;

        // Convertir la tasa anual en BIPS a un número de punto fijo UD60x18
        UD60x18 r_annual = ud((uint256(loan.interestRateBips) * 1e18) / 10000);
        
        // Tiempo transcurrido en años
        UD60x18 timeInYears = ud((elapsedTime * 1e18) / 365 days);
        
        // Calcular rt
        UD60x18 rt = mul(r_annual, timeInYears);
        
        // Calcular e^(rt)
        UD60x18 growthFactor = exp(rt);
        
        // Deuda Total = Principal * e^(rt)
        // Convertir principal a UD60x18, multiplicar y convertir de vuelta
        UD60x18 principal = ud(loan.principalAmount * 1e12);
        UD60x18 totalDebt = mul(principal, growthFactor);
        
        return totalDebt.unwrap() / 1e12;
    }

    /**
     * @notice Obtiene el valor del colateral en USD usando el oráculo de Chainlink
     * @param loan El préstamo cuyo colateral evaluar
     * @return El valor del colateral en USD con 6 decimales (para comparar con USDC)
     */
    function _getCollateralValue(
        Loan memory loan
    ) internal view returns (uint256) {
        // Obtener el precio de ETH en USD del oráculo de Chainlink
        (, int256 ethPriceUSD,,,) = priceFeed.latestRoundData();
        require(ethPriceUSD > 0, "DebtHook: Invalid price feed");
        
        // Chainlink devuelve precios con 8 decimales
        uint8 priceFeedDecimals = priceFeed.decimals();
        
        // Calcular valor del colateral:
        // collateralAmount está en wei (18 decimales)
        // ethPriceUSD tiene 8 decimales
        // Queremos el resultado en 6 decimales (como USDC)
        
        // valor = (collateralAmount * ethPriceUSD) / (10^(18 + 8 - 6))
        uint256 value = (loan.collateralAmount * uint256(ethPriceUSD)) / 10**(18 + priceFeedDecimals - 6);
        
        return value;
    }

    // --- Public View Functions ---
    
    /**
     * @notice Get loan details by ID
     * @param loanIdNum The numeric ID of the loan
     * @return The loan details
     */
    function getLoan(uint256 loanIdNum) public view returns (Loan memory) {
        // Need to look up the loan by iterating through stored loans
        // This is inefficient but matches the test expectations
        uint256 currentCounter = loanCounter;
        for (uint256 i = 1; i <= currentCounter; i++) {
            if (i == loanIdNum) {
                // Try to find loan with this counter value
                // We need to iterate through all loans to find one created with this counter
                // For simplicity, we'll reconstruct potential loan IDs
                // This is a temporary solution - in production, we'd maintain a mapping
                
                // Since we don't know the exact timestamp and borrower, we need a different approach
                // Let's add a mapping to track numeric IDs to bytes32 IDs
                return loans[loanIdMapping[loanIdNum]];
            }
        }
        return Loan(bytes32(0), address(0), address(0), 0, 0, 0, 0, 0, LoanStatus.Active);
    }
    
    /**
     * @notice Get all loans for a borrower
     * @param borrower The borrower address
     * @return Array of loan IDs
     */
    function getBorrowerLoans(address borrower) public view returns (uint256[] memory) {
        return borrowerLoans[borrower];
    }
    
    /**
     * @notice Get all loans for a lender
     * @param lender The lender address
     * @return Array of loan IDs
     */
    function getLenderLoans(address lender) public view returns (uint256[] memory) {
        return lenderLoans[lender];
    }
    
    /**
     * @notice Calculate the current repayment amount for a loan
     * @param loan The loan to calculate repayment for
     * @return The total amount to repay (principal + interest)
     */
    function calculateRepaymentAmount(Loan memory loan) public view returns (uint256) {
        return _calculateCurrentDebt(loan);
    }
    
    /**
     * @notice Helper to repay loan by numeric ID (for testing)
     * @param loanIdNum The numeric loan ID
     */
    function repayLoan(uint256 loanIdNum) external {
        bytes32 loanId = loanIdMapping[loanIdNum];
        _repayLoanInternal(loanId);
    }
    
    /**
     * @notice Check if a loan is liquidatable
     * @param loan The loan to check
     * @return True if the loan can be liquidated
     */
    function isLiquidatable(Loan memory loan) public view returns (bool) {
        // Check if loan is active
        if (loan.status != LoanStatus.Active) return false;
        
        // Calculate health factor
        uint256 collateralValue = _getCollateralValue(loan);
        uint256 currentDebt = _calculateCurrentDebt(loan);
        
        // Health factor = collateralValue / currentDebt
        // Liquidatable if health factor < 1.5 (150%)
        return (collateralValue * 100) < (currentDebt * 150);
    }

    // --- Hook Permissions ---
    // Este Hook no reacciona a los eventos del pool, sino que lo *utiliza* como una herramienta.
    // Por lo tanto, no se necesitan permisos de Hook.
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
                beforeSwap: true,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: true, // We'll modify swap amounts for liquidations
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    // --- Hook Implementation ---

    /**
     * @notice Called before a swap to check for liquidatable positions
     * @dev Scans active loans and modifies swap if liquidation is needed
     */
    function _beforeSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata params,
        bytes calldata
    ) internal override returns (bytes4, BeforeSwapDelta, uint24) {
        // Only process swaps in our ETH/USDC pool
        if (Currency.unwrap(key.currency0) != Currency.unwrap(currency0) || 
            Currency.unwrap(key.currency1) != Currency.unwrap(currency1)) {
            return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
        }

        // Find the first liquidatable loan
        bytes32 liquidatableLoanId = _findLiquidatableLoan();
        
        if (liquidatableLoanId == bytes32(0)) {
            // No liquidatable loans found
            return (IHooks.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
        }

        Loan storage loan = loans[liquidatableLoanId];
        
        // Calculate liquidation amounts
        (uint256 collateralToLiquidate, uint256 debtToRepay) = _calculateLiquidationAmounts(loan);
        
        // Store liquidation data in transient storage for afterSwap
        assembly {
            tstore(LIQUIDATION_LOAN_ID, liquidatableLoanId)
            tstore(LIQUIDATION_COLLATERAL_AMOUNT, collateralToLiquidate)
            tstore(LIQUIDATION_DEBT_AMOUNT, debtToRepay)
        }

        // Modify swap to include liquidation
        // If swapping ETH for USDC (zeroForOne), we add collateral to sell
        // If swapping USDC for ETH (!zeroForOne), we need USDC to cover debt
        BeforeSwapDelta delta;
        if (params.zeroForOne) {
            // Selling ETH for USDC - perfect for liquidation
            // Add collateral amount to the ETH being sold
            delta = BeforeSwapDelta.wrap(int256(collateralToLiquidate) << 128);
        } else {
            // Buying ETH with USDC - need to ensure enough USDC output
            // This is more complex and may need different handling
            delta = BeforeSwapDeltaLibrary.ZERO_DELTA;
        }

        return (IHooks.beforeSwap.selector, delta, 0);
    }

    /**
     * @notice Called after a swap to complete liquidation
     * @dev Distributes liquidation proceeds and updates loan state
     */
    function _afterSwap(
        address,
        PoolKey calldata key,
        SwapParams calldata,
        BalanceDelta delta,
        bytes calldata
    ) internal override returns (bytes4, int128) {
        // Only process our pool
        if (Currency.unwrap(key.currency0) != Currency.unwrap(currency0) || 
            Currency.unwrap(key.currency1) != Currency.unwrap(currency1)) {
            return (BaseHook.afterSwap.selector, 0);
        }

        // Retrieve liquidation data from transient storage
        bytes32 loanId;
        uint256 collateralAmount;
        uint256 debtAmount;
        
        assembly {
            loanId := tload(LIQUIDATION_LOAN_ID)
            collateralAmount := tload(LIQUIDATION_COLLATERAL_AMOUNT)
            debtAmount := tload(LIQUIDATION_DEBT_AMOUNT)
        }

        // If no liquidation was triggered, return
        if (loanId == bytes32(0)) {
            return (IHooks.afterSwap.selector, 0);
        }

        // Clear transient storage
        assembly {
            tstore(LIQUIDATION_LOAN_ID, 0)
            tstore(LIQUIDATION_COLLATERAL_AMOUNT, 0)
            tstore(LIQUIDATION_DEBT_AMOUNT, 0)
        }

        // Complete the liquidation
        _completeLiquidation(loanId, collateralAmount, debtAmount, delta);

        return (IHooks.afterSwap.selector, 0);
    }

    /**
     * @notice Find the first liquidatable loan
     * @dev Iterates through active loans to find one that can be liquidated
     */
    function _findLiquidatableLoan() internal view returns (bytes32) {
        uint256 loanCount = loanCounter;
        
        for (uint256 i = 1; i <= loanCount; i++) {
            bytes32 loanId = keccak256(abi.encodePacked(i));
            Loan storage loan = loans[loanId];
            
            // Skip if loan is not active
            if (loan.status != LoanStatus.Active) continue;
            
            // Check if loan is liquidatable
            if (isLiquidatable(loan)) {
                return loanId;
            }
        }
        
        return bytes32(0);
    }

    /**
     * @notice Calculate amounts for liquidation
     * @dev Returns collateral to sell and debt to repay
     */
    function _calculateLiquidationAmounts(Loan storage loan) 
        internal 
        view 
        returns (uint256 collateralToLiquidate, uint256 debtToRepay) 
    {
        // Get current debt including interest
        uint256 totalDebt = calculateRepaymentAmount(loan);
        
        // In a full liquidation, we take all collateral and repay all debt
        collateralToLiquidate = loan.collateralAmount;
        debtToRepay = totalDebt;
        
        // TODO: Implement partial liquidations if needed
    }

    /**
     * @notice Complete the liquidation after swap
     * @dev Distributes proceeds and updates loan state
     */
    function _completeLiquidation(
        bytes32 loanId,
        uint256 collateralLiquidated,
        uint256 debtRepaid,
        BalanceDelta swapDelta
    ) internal {
        Loan storage loan = loans[loanId];
        
        // Calculate proceeds from swap (USDC received for ETH sold)
        uint256 usdcReceived = uint256(int256(-swapDelta.amount1()));
        
        // Calculate penalty (5% of USDC received)
        uint256 penalty = (usdcReceived * PENALTY_BIPS) / 10000;
        
        // Distribute funds:
        // 1. Repay lender (principal + interest - penalty)
        uint256 lenderAmount = usdcReceived > penalty ? usdcReceived - penalty : 0;
        if (lenderAmount > debtRepaid) {
            lenderAmount = debtRepaid; // Cap at actual debt
        }
        
        // For V4 hooks, we need to handle transfers differently
        // The hook receives tokens from the swap, and we need to distribute them
        
        // 2. Transfer penalty to treasury
        if (penalty > 0) {
            ERC20(Currency.unwrap(currency1)).transfer(treasury, penalty);
        }
        
        // 3. Transfer remaining to lender
        if (lenderAmount > 0) {
            ERC20(Currency.unwrap(currency1)).transfer(loan.lender, lenderAmount);
        }
        
        // 4. Return any excess to borrower (rare in liquidation)
        uint256 excessUSDC = usdcReceived > (lenderAmount + penalty) ? 
            usdcReceived - lenderAmount - penalty : 0;
        if (excessUSDC > 0) {
            ERC20(Currency.unwrap(currency1)).transfer(loan.borrower, excessUSDC);
        }
        
        // Update loan status
        loan.status = LoanStatus.Liquidated;
        
        // Emit liquidation event
        emit LoanLiquidated(
            loanId,
            usdcReceived,
            excessUSDC
        );
    }
}
