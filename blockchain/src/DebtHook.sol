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
import {SwapParams} from "v4-core/src/types/PoolOperation.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {IPriceFeed} from "./interfaces/IPriceFeed.sol"; // Interfaz para Chainlink
import {IDebtHook} from "./interfaces/IDebtHook.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {UD60x18, ud} from "prb-math/UD60x18.sol";
import {mul, exp} from "prb-math/ud60x18/Math.sol";

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
        Loan storage loan = loans[loanId];
        
        // Validaciones
        require(msg.sender == loan.borrower, "DebtHook: Not the borrower");
        require(loan.status == LoanStatus.Active, "DebtHook: Loan not active");
        require(
            block.timestamp >= loan.maturityTimestamp,
            "DebtHook: Loan not mature"
        );

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
        int256 ethPriceUSD = priceFeed.latestAnswer();
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
}
