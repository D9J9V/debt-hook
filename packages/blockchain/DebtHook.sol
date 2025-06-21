// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol"; //
import {Hooks} from "v4-core/src/libraries/Hooks.sol"; //
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol"; //
import {PoolKey} from "v4-core/src/types/PoolKey.sol"; //
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol"; //
import {IPriceFeed} from "./interfaces/IPriceFeed.sol"; // Interfaz para Chainlink

// DebtHook es un contrato que gestiona posiciones de deuda colateralizada.
// Utiliza un pool de Uniswap v4 como capa de liquidación.
contract DebtHook is BaseHook {
    // --- State Variables ---

    // Oráculo de precios para obtener el valor del colateral (ej. ETH/USD)
    IPriceFeed public immutable priceFeed;

    // PoolKey y PoolId del pool USDC/ETH que se usará para liquidaciones
    PoolKey public immutable liquidationPoolKey;
    PoolId public immutable liquidationPoolId;

    // Estructura para almacenar los detalles de cada préstamo
    struct Loan {
        bytes32 id;
        address borrower;
        address lender;
        uint256 collateralAmount; // Cantidad de ETH, ej. en wei
        uint256 principalAmount; // Cantidad de USDC, ej. con 6 decimales
        uint64 startTime; // t_0
        uint64 maturityTime; // T
        uint32 interestRateBips; // Tasa de interés anual en BIPS (ej. 1000 = 10%)
        LoanStatus status;
    }

    enum LoanStatus {
        Active,
        Repaid,
        Liquidated,
        Defaulted
    }

    // Mapping para almacenar todas las posiciones de préstamo
    mapping(bytes32 => Loan) public loans;
    uint256 private loanCounter; // Para generar IDs únicos

    // --- Events ---
    event LoanCreated(
        bytes32 indexed loanId,
        address indexed borrower,
        address indexed lender,
        uint256 collateral,
        uint256 principal
    );
    event LoanRepaid(bytes32 indexed loanId);
    event LoanLiquidated(
        bytes32 indexed loanId,
        uint256 debtAmount,
        uint256 collateralSold,
        uint256 proceeds
    );
    event CollateralClaimed(bytes32 indexed loanId);

    // --- Constructor ---
    constructor(
        IPoolManager _poolManager,
        address _priceFeedAddress,
        PoolKey memory _liquidationPoolKey
    ) BaseHook(_poolManager) {
        priceFeed = IPriceFeed(_priceFeedAddress);
        liquidationPoolKey = _liquidationPoolKey;
        liquidationPoolId = PoolIdLibrary.toId(_liquidationPoolKey); //
    }

    // --- Core Logic: Loan Lifecycle Functions ---

    /**
     * @notice Crea una nueva posición de préstamo. El prestamista debe haber aprobado
     * al prestatario para gastar su USDC. El prestatario envía ETH como colateral.
     * @param lender La dirección del prestamista.
     * @param principalAmount La cantidad de USDC prestada.
     * @param maturityTimestamp El timestamp de vencimiento del préstamo.
     * @param rateBips La tasa de interés anual fija en BIPS.
     */
    function createLoan(
        address lender,
        uint256 principalAmount,
        uint64 maturityTimestamp,
        uint32 rateBips
    ) external payable {
        // Lógica para crear el préstamo:
        // 1. Validar parámetros (ej. msg.value > 0).
        // 2. Generar un nuevo loanId.
        // 3. Transferir `principalAmount` de USDC desde `lender` hacia `msg.sender` (borrower).
        // 4. Almacenar el colateral (msg.value) en este contrato.
        // 5. Crear y guardar la nueva struct `Loan` en el mapping `loans`.
        // 6. Emitir el evento `LoanCreated`.
    }

    /**
     * @notice Permite al prestatario repagar su deuda al vencimiento.
     * @param loanId El ID del préstamo a repagar.
     */
    function repayLoan(bytes32 loanId) external {
        // Lógica para repagar el préstamo:
        // 1. Cargar el `Loan` desde el storage.
        // 2. Verificar que msg.sender es el prestatario y que el estado es `Active`.
        // 3. Calcular la deuda total (`$D_t$`).
        // 4. Transferir la cantidad de la deuda en USDC desde el prestatario a este contrato.
        // 5. Transferir la deuda al prestamista.
        // 6. Transferir el colateral de vuelta al prestatario.
        // 7. Actualizar el estado del préstamo a `Repaid` y emitir evento.
    }

    /**
     * @notice Función pública que puede ser llamada por un Keeper para liquidar una posición.
     * @param loanId El ID del préstamo a liquidar.
     */
    function liquidate(bytes32 loanId) external {
        // Lógica de liquidación:
        // 1. Cargar el `Loan` desde el storage.
        // 2. Verificar que el estado del préstamo es `Active`.
        // 3. Calcular la deuda actual (`$D_t$`) con la función interna `_calculateCurrentDebt`.
        // 4. Obtener el valor del colateral (`$C_t$`) con la función interna `_getCollateralValue`.
        // 5. **Verificar la condición de liquidación: require(collateralValue <= currentDebt, "Loan is not underwater");**
        // 6. Si la condición se cumple, llamar a `poolManager.swap` para vender todo el colateral (ETH) por USDC.
        // 7. Distribuir el USDC obtenido:
        //    - Pagar al prestamista hasta el monto de la deuda.
        //    - Enviar el remanente (si existe) al prestatario.
        //    - El prestamista asume cualquier pérdida si los fondos no son suficientes.
        // 8. Pagar un bono de liquidación al `msg.sender` (el Keeper).
        // 9. Actualizar el estado a `Liquidated` y emitir evento.
    }

    // --- Helper & View Functions ---

    function _calculateCurrentDebt(
        Loan storage loan
    ) internal view returns (uint256) {
        // Implementación de la fórmula D_t = D_0 * e^(rt)
        // Nota: la exponenciación en Solidity requiere librerías de punto fijo o aproximaciones.
        // Para una tasa fija, una aproximación lineal simple también puede ser una opción inicial:
        // debt = principal + (principal * rate * time_elapsed) / (YEAR_IN_SECONDS * 10000);
        return 0; // Placeholder
    }

    function _getCollateralValue(
        Loan storage loan
    ) internal view returns (uint256) {
        // Llama al oráculo de Chainlink para obtener el precio de ETH en USD.
        // Multiplica el precio por la cantidad de colateral.
        // Considerar la conversión de decimales.
        return 0; // Placeholder
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
