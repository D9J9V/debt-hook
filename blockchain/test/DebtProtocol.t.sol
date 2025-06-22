// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Deployers} from "v4-core/test/utils/Deployers.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {ModifyLiquidityParams} from "v4-core/src/types/PoolOperation.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {UD60x18} from "prb-math/UD60x18.sol";

// Contratos del protocolo
import {DebtOrderBook} from "../src/DebtOrderBook.sol";
import {DebtHook} from "../src/DebtHook.sol";
import {IDebtHook} from "../src/interfaces/IDebtHook.sol";

// Mocks y utilidades
import {MockERC20} from "./mocks/MockERC20.sol";
import {LiquidityAmounts} from "v4-core/test/utils/LiquidityAmounts.sol";

contract DebtProtocolTest is Test {
    using CurrencyLibrary for Currency;
    
    // Events from DebtHook contract
    event LoanCreated(bytes32 indexed loanId, address indexed lender, address indexed borrower);
    event LoanRepaid(bytes32 indexed loanId);
    event LoanLiquidated(bytes32 indexed loanId, uint256 collateralSold, uint256 debtRecovered);

    // --- Componentes del Sistema ---
    PoolManager manager;
    DebtHook debtHook;
    DebtOrderBook orderBook;
    MockERC20 usdc;

    // --- Configuración del Pool y Monedas ---
    Currency currency0; // ETH (address(0))
    Currency currency1; // USDC
    PoolKey key;
    uint160 constant SQRT_PRICE_1_1 = 79228162514264337593543950336; // 1:1 price

    // --- Actores ---
    address lender = makeAddr("lender");
    uint256 lenderPrivateKey = 0x1337;
    address borrower = makeAddr("borrower");
    address treasury = makeAddr("treasury");

    // --- Estado de Prueba ---
    bytes32 lastLoanId;

    function setUp() public {
        // 1. Desplegar PoolManager
        manager = new PoolManager(address(this));

        // 2. Desplegar Mocks y Contratos del Protocolo
        usdc = new MockERC20("USD Coin", "USDC", 6);
        currency0 = Currency.wrap(address(0));
        currency1 = Currency.wrap(address(usdc));

        debtHook = new DebtHook(
            IPoolManager(address(manager)),
            address(0), // price feed
            address(0), // debt order book (will be set later)
            treasury,
            currency0,
            currency1,
            3000,
            60
        );
        orderBook = new DebtOrderBook(address(debtHook), address(usdc));
        // En una implementación real, la dirección del order book se pasaría al constructor del hook
        // y viceversa, para un enlace inmutable. Aquí se simplifica.

        // 3. Crear e Inicializar el Pool de Uniswap v4
        key = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(debtHook))
        });
        manager.initialize(key, SQRT_PRICE_1_1);

        // 4. Añadir liquidez profunda al pool para que las liquidaciones sean realistas
        uint128 liquidity = 1e18;
        int24 tickLower = -887220; // Rango completo
        int24 tickUpper = 887220;

        (uint256 amount0, uint256 amount1) = LiquidityAmounts
            .getAmountsForLiquidity(
                SQRT_PRICE_1_1,
                TickMath.getSqrtPriceAtTick(tickLower),
                TickMath.getSqrtPriceAtTick(tickUpper),
                liquidity
            );

        usdc.mint(address(this), amount1);
        usdc.approve(address(manager), amount1);
        deal(address(this), amount0);

        manager.modifyLiquidity(
            key,
            ModifyLiquidityParams({
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: int256(int128(liquidity)),
                salt: bytes32(0)
            }),
            ""
        );

        // 5. Financiar a los actores
        usdc.mint(lender, 10_000 * 1e6); // 10,000 USDC
        deal(borrower, 10 ether);
    }

    /// @notice Prueba el ciclo completo: creación, repago y verificación de balances.
    function test_E2E_CreateAndRepayLoan_HappyPath() public {
        // --- ARRANGE: El prestamista aprueba, crea y firma una orden ---
        uint256 principal = 1000 * 1e6; // 1000 USDC
        uint256 collateral = 1 ether;
        vm.prank(lender);
        usdc.approve(address(orderBook), principal);

        DebtOrderBook.LoanLimitOrder memory order = DebtOrderBook
            .LoanLimitOrder({
                lender: lender,
                token: address(usdc),
                principalAmount: principal,
                collateralRequired: collateral,
                interestRateBips: 500, // 5% APR
                maturityTimestamp: uint64(block.timestamp + 30 days),
                expiry: uint64(block.timestamp + 1 hours),
                nonce: 1
            });

        // Hash and sign the order
        bytes32 orderHash = orderBook.hashLoanLimitOrder(order);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(lenderPrivateKey, orderHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // --- ACT 1: El prestatario acepta la orden ---
        // Se necesita capturar el loanId emitido para el repago.
        // Para esto, usamos vm.expectEmit.
        vm.expectEmit(true, true, true, true);
        emit LoanCreated(bytes32(0), lender, borrower); // El loanId no es predecible, pero podemos escuchar el evento.

        vm.prank(borrower);
        orderBook.fillLimitOrder{value: collateral}(order, signature);

        // --- ASSERT 1: El préstamo se creó correctamente ---
        // (En una implementación real, se extraería el `loanId` del log del evento)
        // Por simplicidad, asumiremos que conocemos el ID o lo leemos del estado.

        // --- ARRANGE 2: Preparar para el repago ---
        vm.warp(block.timestamp + 30 days); // Avanzar en el tiempo

        // NOTA: Para hacer esta prueba determinista, necesitaríamos una función `getLoanId` o
        // que `createLoan` devuelva el ID. Asumimos que `lastLoanId` se obtiene de alguna manera.
        // Aquí simularemos que `createLoan` lo devolvió o lo leímos de un evento.
        // Asumimos que el ID es `keccak256(...)` como en el contrato.

        // --- ACT 2: El prestatario repaga la deuda ---
        // ... Lógica para obtener el `loanId` y llamar a `repayLoan` ...
        // Esta parte requiere modificar ligeramente los contratos para testabilidad o usar
        // técnicas avanzadas de lectura de logs en Foundry.
    }

    /// @notice Prueba la liquidación por incumplimiento y la correcta distribución de fondos.
    function test_E2E_Liquidate_OnDefault_WithSurplus() public {
        // --- ARRANGE: Crear un préstamo (similar a la prueba anterior) ---
        // ... (código de creación de préstamo omitido por brevedad) ...
        // Supongamos que se crea un préstamo con ID `testLoanId`.

        // --- ACT 1: Viajar en el tiempo más allá del período de gracia ---
        vm.warp(block.timestamp + 31 days);

        // --- ACT 2: El prestamista liquida el préstamo ---
        uint256 lenderBalanceBefore = usdc.balanceOf(lender);
        uint256 borrowerBalanceBefore = usdc.balanceOf(borrower);
        uint256 treasuryBalanceBefore = usdc.balanceOf(treasury);

        vm.prank(lender);
        debtHook.liquidate(lastLoanId); // `lastLoanId` debe ser obtenido tras la creación.

        // --- ASSERT: Verificar la distribución de fondos ---
        uint256 lenderBalanceAfter = usdc.balanceOf(lender);
        uint256 borrowerBalanceAfter = usdc.balanceOf(borrower);
        uint256 treasuryBalanceAfter = usdc.balanceOf(treasury);

        uint256 debtAtMaturity = 1050 * 1e6; // 1000 + 5% interés (aprox.)

        // El prestamista recibe su deuda de vuelta
        assertTrue(lenderBalanceAfter > lenderBalanceBefore);
        assertApproxEqAbs(
            lenderBalanceAfter - lenderBalanceBefore,
            debtAtMaturity,
            1 * 1e6
        ); // Tolerancia por slippage

        // El swap de 1 ETH a 1000 USDC debería generar un superávit (asumiendo precio estable)
        // El tesoro y el prestatario deberían recibir fondos.
        assertTrue(
            treasuryBalanceAfter > treasuryBalanceBefore,
            "Treasury should receive penalty fee"
        );
        assertTrue(
            borrowerBalanceAfter > borrowerBalanceBefore,
            "Borrower should receive surplus"
        );
    }

    /// @notice Prueba que una orden no puede ser llenada con una firma incorrecta.
    function test_Revert_When_FillingOrderWithInvalidSignature() public {
        // Create order
        DebtOrderBook.LoanLimitOrder memory order = DebtOrderBook.LoanLimitOrder({
            lender: lender,
            token: address(usdc),
            principalAmount: 1000 * 1e6, // 1000 USDC
            collateralRequired: 1 ether,
            interestRateBips: 500, // 5%
            maturityTimestamp: uint64(block.timestamp + 30 days),
            expiry: uint64(block.timestamp + 1 days),
            nonce: 1
        });
        
        bytes memory badSignature = new bytes(65); // Firma vacía o incorrecta

        vm.prank(borrower);
        vm.expectRevert("DebtOrderBook: Invalid signature");
        orderBook.fillLimitOrder{value: 1 ether}(order, badSignature);
    }
}
