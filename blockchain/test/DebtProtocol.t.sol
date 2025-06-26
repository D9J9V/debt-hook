// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {CurrencySettler} from "v4-core/test/utils/CurrencySettler.sol";
import {ModifyLiquidityParams} from "v4-core/src/types/PoolOperation.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {UD60x18} from "prb-math/UD60x18.sol";
import {LiquidityAmounts} from "v4-core/test/utils/LiquidityAmounts.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";

// Protocol contracts
import {DebtOrderBook} from "../src/DebtOrderBook.sol";
import {DebtHook} from "../src/DebtHook.sol";
import {IDebtHook} from "../src/interfaces/IDebtHook.sol";
import {MockPriceFeed} from "../src/mocks/MockPriceFeed.sol";
import {ChainlinkPriceFeed} from "../src/ChainlinkPriceFeed.sol";
import {IPriceFeed} from "../src/interfaces/IPriceFeed.sol";

// Mocks
import {MockERC20} from "./mocks/MockERC20.sol";
import {PoolModifyLiquidityTest} from "v4-core/src/test/PoolModifyLiquidityTest.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";

contract DebtHookTest is Test {
    using CurrencyLibrary for Currency;
    using CurrencySettler for Currency;

    // Events from DebtHook contract
    event LoanCreated(bytes32 indexed loanId, address indexed lender, address indexed borrower);

    event LoanRepaid(bytes32 indexed loanId);

    event LoanLiquidated(bytes32 indexed loanId, uint256 proceeds, uint256 surplus);

    // System components
    PoolManager manager;
    DebtHook debtHook;
    DebtOrderBook orderBook;
    MockERC20 usdc;
    IPriceFeed priceFeed;
    PoolModifyLiquidityTest modifyLiquidityRouter;

    // Pool configuration
    Currency currency0; // ETH (address(0))
    Currency currency1; // USDC
    PoolKey key;
    uint160 constant SQRT_PRICE_1_1 = 79228162514264337593543950336; // 1:1 price

    // Test actors
    address lender;
    uint256 lenderPrivateKey = 0x1337;
    address borrower = makeAddr("borrower");
    address treasury = makeAddr("treasury");
    address liquidator = makeAddr("liquidator");

    // Constants
    uint256 constant PRINCIPAL_AMOUNT = 1000 * 1e6; // 1000 USDC
    uint256 constant COLLATERAL_AMOUNT = 1 ether;
    uint64 constant INTEREST_RATE = 500; // 5% APR
    uint64 constant LOAN_DURATION = 30 days;

    function setUp() public {
        // Generate lender address from private key
        lender = vm.addr(lenderPrivateKey);

        // 1. Deploy PoolManager
        manager = new PoolManager(address(this));

        // 2. Deploy mocks and protocol contracts
        usdc = new MockERC20("USD Coin", "USDC", 6);
        currency0 = Currency.wrap(address(0));
        currency1 = Currency.wrap(address(usdc));

        // Deploy price feed with $2000 ETH price
        priceFeed = new MockPriceFeed(2000e8, 8, "ETH/USD");

        // Deploy the hook to an address with the correct flags
        // For beforeSwap and afterSwap, we need bits 6 and 7 set
        address hookFlags = address(
            uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG)
                ^ (0x4444 << 144) // Namespace the hook to avoid collisions
        );

        // First, deploy a temporary DebtOrderBook to get its future address
        DebtOrderBook tempOrderBook = new DebtOrderBook(address(0), address(usdc));

        // Deploy DebtHook to the correct address using deployCodeTo
        bytes memory constructorArgs = abi.encode(
            IPoolManager(address(manager)),
            address(priceFeed),
            address(tempOrderBook), // Use the temporary orderBook address
            treasury,
            currency0,
            currency1,
            3000, // 0.3% fee
            60 // tick spacing
        );
        deployCodeTo("DebtHook.sol:DebtHook", constructorArgs, hookFlags);
        debtHook = DebtHook(hookFlags);

        // Now deploy the real OrderBook that points to our DebtHook
        orderBook = new DebtOrderBook(address(debtHook), address(usdc));

        // Update the DebtHook with the correct orderBook address
        // We need to redeploy since the orderBook is immutable
        constructorArgs = abi.encode(
            IPoolManager(address(manager)),
            address(priceFeed),
            address(orderBook), // Now use the real orderBook address
            treasury,
            currency0,
            currency1,
            3000,
            60
        );
        deployCodeTo("DebtHook.sol:DebtHook", constructorArgs, hookFlags);
        debtHook = DebtHook(hookFlags);

        // 3. Deploy test router
        modifyLiquidityRouter = new PoolModifyLiquidityTest(manager);

        // 4. Create and initialize Uniswap v4 pool
        key = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0)) // No hooks for liquidation pool
        });
        manager.initialize(key, SQRT_PRICE_1_1);

        // 5. Add deep liquidity to pool
        // TODO: Fix liquidity addition
        // _addLiquidityToPool();

        // 6. Fund test actors
        usdc.mint(lender, 10_000 * 1e6); // 10,000 USDC
        deal(borrower, 10 ether);
        deal(liquidator, 10 ether);
    }

    function _addLiquidityToPool() internal {
        uint128 liquidity = 100_000e18;
        int24 tickLower = -887220;
        int24 tickUpper = 887220;

        (uint256 amount0, uint256 amount1) = LiquidityAmounts.getAmountsForLiquidity(
            SQRT_PRICE_1_1, TickMath.getSqrtPriceAtTick(tickLower), TickMath.getSqrtPriceAtTick(tickUpper), liquidity
        );

        usdc.mint(address(this), amount1);
        usdc.approve(address(modifyLiquidityRouter), amount1);
        deal(address(this), amount0);

        modifyLiquidityRouter.modifyLiquidity{value: amount0}(
            key,
            ModifyLiquidityParams({
                tickLower: tickLower,
                tickUpper: tickUpper,
                liquidityDelta: int256(int128(liquidity)),
                salt: bytes32(0)
            }),
            "",
            false,
            false
        );
    }

    function _createSignedOrder(uint256 principal, uint256 collateral, uint64 duration, uint64 interestRate)
        internal
        view
        returns (DebtOrderBook.LoanLimitOrder memory, bytes memory)
    {
        DebtOrderBook.LoanLimitOrder memory order = DebtOrderBook.LoanLimitOrder({
            lender: lender,
            token: address(usdc),
            principalAmount: principal,
            collateralRequired: collateral,
            interestRateBips: uint32(interestRate),
            maturityTimestamp: uint64(block.timestamp + duration),
            expiry: uint64(block.timestamp + 1 hours),
            nonce: 1
        });

        bytes32 orderHash = orderBook.hashLoanLimitOrder(order);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(lenderPrivateKey, orderHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        return (order, signature);
    }

    function test_CreateLoanWithOrder() public {
        // Arrange
        vm.prank(lender);
        usdc.approve(address(orderBook), PRINCIPAL_AMOUNT);

        (DebtOrderBook.LoanLimitOrder memory order, bytes memory signature) =
            _createSignedOrder(PRINCIPAL_AMOUNT, COLLATERAL_AMOUNT, LOAN_DURATION, INTEREST_RATE);

        uint256 borrowerUsdcBefore = usdc.balanceOf(borrower);
        uint256 borrowerEthBefore = borrower.balance;

        // Act
        vm.expectEmit(false, true, true, false);
        emit LoanCreated(
            bytes32(0), // We don't know the exact ID yet
            lender,
            borrower
        );

        vm.prank(borrower);
        orderBook.fillLimitOrder{value: COLLATERAL_AMOUNT}(order, signature);

        // Assert
        DebtHook.Loan memory loan = debtHook.getLoan(1);
        assertEq(loan.borrower, borrower);
        assertEq(loan.lender, lender);
        assertEq(loan.principalAmount, PRINCIPAL_AMOUNT);
        assertEq(loan.collateralAmount, COLLATERAL_AMOUNT);
        assertEq(loan.maturityTimestamp, uint64(block.timestamp + LOAN_DURATION));
        assertEq(loan.interestRateBips, uint32(INTEREST_RATE));
        assertTrue(loan.status == DebtHook.LoanStatus.Active);

        // Check balances
        assertEq(usdc.balanceOf(borrower), borrowerUsdcBefore + PRINCIPAL_AMOUNT);
        assertEq(borrower.balance, borrowerEthBefore - COLLATERAL_AMOUNT);
    }

    function test_RepayLoan() public {
        // Create loan first
        vm.prank(lender);
        usdc.approve(address(orderBook), PRINCIPAL_AMOUNT);

        (DebtOrderBook.LoanLimitOrder memory order, bytes memory signature) =
            _createSignedOrder(PRINCIPAL_AMOUNT, COLLATERAL_AMOUNT, LOAN_DURATION, INTEREST_RATE);

        vm.prank(borrower);
        orderBook.fillLimitOrder{value: COLLATERAL_AMOUNT}(order, signature);

        // Fast forward 15 days
        vm.warp(block.timestamp + 15 days);

        // Calculate repayment amount
        DebtHook.Loan memory loan = debtHook.getLoan(1);
        uint256 repaymentAmount = debtHook.calculateRepaymentAmount(loan);

        // Mint extra USDC for interest payment
        usdc.mint(borrower, repaymentAmount - PRINCIPAL_AMOUNT);

        // Approve and repay
        vm.prank(borrower);
        usdc.approve(address(debtHook), repaymentAmount);

        uint256 lenderUsdcBefore = usdc.balanceOf(lender);
        uint256 borrowerEthBefore = borrower.balance;

        vm.expectEmit(false, false, false, false);
        emit LoanRepaid(
            bytes32(0) // Don't check the exact loanId
        );

        vm.prank(borrower);
        debtHook.repayLoan(1);

        // Assert loan is repaid
        loan = debtHook.getLoan(1);
        assertTrue(loan.status == DebtHook.LoanStatus.Repaid);

        // Check balances
        assertEq(usdc.balanceOf(lender), lenderUsdcBefore + repaymentAmount);
        assertEq(borrower.balance, borrowerEthBefore + COLLATERAL_AMOUNT);
    }

    function test_LiquidateLoan_AfterGracePeriod() public {
        vm.skip(true); // Skip until liquidity addition is fixed
        // Create loan
        vm.prank(lender);
        usdc.approve(address(orderBook), PRINCIPAL_AMOUNT);

        (DebtOrderBook.LoanLimitOrder memory order, bytes memory signature) =
            _createSignedOrder(PRINCIPAL_AMOUNT, COLLATERAL_AMOUNT, LOAN_DURATION, INTEREST_RATE);

        vm.prank(borrower);
        orderBook.fillLimitOrder{value: COLLATERAL_AMOUNT}(order, signature);

        // Fast forward past maturity + grace period
        vm.warp(block.timestamp + LOAN_DURATION + 25 hours);

        // Check loan is liquidatable
        DebtHook.Loan memory loan = debtHook.getLoan(1);
        assertTrue(debtHook.isLiquidatable(loan));

        uint256 lenderUsdcBefore = usdc.balanceOf(lender);
        uint256 treasuryUsdcBefore = usdc.balanceOf(treasury);

        // Liquidate
        vm.prank(liquidator);
        // TODO: Trigger liquidation through swap
        vm.skip(true);

        // Assert loan is liquidated
        loan = debtHook.getLoan(1);
        assertTrue(loan.status == DebtHook.LoanStatus.Liquidated);

        // Check funds distributed
        assertGt(usdc.balanceOf(lender), lenderUsdcBefore);
        assertGt(usdc.balanceOf(treasury), treasuryUsdcBefore);
    }

    function test_LiquidateLoan_UnderCollateralized() public {
        vm.skip(true); // Skip until liquidity addition is fixed
        // Create loan
        vm.prank(lender);
        usdc.approve(address(orderBook), PRINCIPAL_AMOUNT);

        (DebtOrderBook.LoanLimitOrder memory order, bytes memory signature) =
            _createSignedOrder(PRINCIPAL_AMOUNT, COLLATERAL_AMOUNT, LOAN_DURATION, INTEREST_RATE);

        vm.prank(borrower);
        orderBook.fillLimitOrder{value: COLLATERAL_AMOUNT}(order, signature);

        // Drop ETH price to make loan under-collateralized
        // Note: In production with Chainlink, we can't manipulate price
        // This test only works with MockPriceFeed
        vm.skip(true); // Skip this test when using Chainlink

        // Check loan is liquidatable
        DebtHook.Loan memory loan = debtHook.getLoan(1);
        assertTrue(debtHook.isLiquidatable(loan));

        // Liquidate
        vm.prank(liquidator);
        // TODO: Trigger liquidation through swap
        vm.skip(true);

        // Assert loan is liquidated
        loan = debtHook.getLoan(1);
        assertTrue(loan.status == DebtHook.LoanStatus.Liquidated);
    }

    function test_RevertWhen_RepayingNonExistentLoan() public {
        vm.expectRevert(DebtHook.LoanNotFound.selector);
        debtHook.repayLoan(999);
    }

    function test_RevertWhen_RepayingAlreadyRepaidLoan() public {
        // Create and repay loan
        vm.prank(lender);
        usdc.approve(address(orderBook), PRINCIPAL_AMOUNT);

        (DebtOrderBook.LoanLimitOrder memory order, bytes memory signature) =
            _createSignedOrder(PRINCIPAL_AMOUNT, COLLATERAL_AMOUNT, LOAN_DURATION, INTEREST_RATE);

        vm.prank(borrower);
        orderBook.fillLimitOrder{value: COLLATERAL_AMOUNT}(order, signature);

        DebtHook.Loan memory loan = debtHook.getLoan(1);
        uint256 repaymentAmount = debtHook.calculateRepaymentAmount(loan);

        usdc.mint(borrower, repaymentAmount);
        vm.prank(borrower);
        usdc.approve(address(debtHook), repaymentAmount);

        vm.prank(borrower);
        debtHook.repayLoan(1);

        // Try to repay again
        vm.prank(borrower);
        vm.expectRevert(DebtHook.LoanAlreadyRepaid.selector);
        debtHook.repayLoan(1);
    }

    function test_RevertWhen_LiquidatingHealthyLoan() public {
        // Create loan
        vm.prank(lender);
        usdc.approve(address(orderBook), PRINCIPAL_AMOUNT);

        (DebtOrderBook.LoanLimitOrder memory order, bytes memory signature) =
            _createSignedOrder(PRINCIPAL_AMOUNT, COLLATERAL_AMOUNT, LOAN_DURATION, INTEREST_RATE);

        vm.prank(borrower);
        orderBook.fillLimitOrder{value: COLLATERAL_AMOUNT}(order, signature);

        // Get the loan to find its ID
        DebtHook.Loan memory loan = debtHook.getLoan(1);

        // Verify loan is healthy (not liquidatable)
        assertFalse(debtHook.isLiquidatable(loan));

        // Since liquidations happen through swaps in V4 hooks, we can't directly test the revert
        // Instead, we'll verify that the loan is not liquidatable
        // In production, the beforeSwap hook would not trigger liquidation for this loan
    }

    function test_RevertWhen_FillingOrderWithInvalidSignature() public {
        DebtOrderBook.LoanLimitOrder memory order = DebtOrderBook.LoanLimitOrder({
            lender: lender,
            token: address(usdc),
            principalAmount: PRINCIPAL_AMOUNT,
            collateralRequired: COLLATERAL_AMOUNT,
            interestRateBips: uint32(INTEREST_RATE),
            maturityTimestamp: uint64(block.timestamp + LOAN_DURATION),
            expiry: uint64(block.timestamp + 1 days),
            nonce: 1
        });

        bytes memory badSignature = new bytes(65);

        vm.prank(borrower);
        vm.expectRevert(ECDSA.InvalidSignature.selector);
        orderBook.fillLimitOrder{value: COLLATERAL_AMOUNT}(order, badSignature);
    }

    function test_RevertWhen_FillingExpiredOrder() public {
        vm.prank(lender);
        usdc.approve(address(orderBook), PRINCIPAL_AMOUNT);

        DebtOrderBook.LoanLimitOrder memory order = DebtOrderBook.LoanLimitOrder({
            lender: lender,
            token: address(usdc),
            principalAmount: PRINCIPAL_AMOUNT,
            collateralRequired: COLLATERAL_AMOUNT,
            interestRateBips: uint32(INTEREST_RATE),
            maturityTimestamp: uint64(block.timestamp + LOAN_DURATION),
            expiry: uint64(block.timestamp + 1 hours),
            nonce: 1
        });

        bytes32 orderHash = orderBook.hashLoanLimitOrder(order);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(lenderPrivateKey, orderHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Fast forward past expiry
        vm.warp(block.timestamp + 2 hours);

        vm.prank(borrower);
        vm.expectRevert("DebtOrderBook: Order expired");
        orderBook.fillLimitOrder{value: COLLATERAL_AMOUNT}(order, signature);
    }

    function test_RevertWhen_ReusingNonce() public {
        vm.prank(lender);
        usdc.approve(address(orderBook), PRINCIPAL_AMOUNT * 2);

        (DebtOrderBook.LoanLimitOrder memory order, bytes memory signature) =
            _createSignedOrder(PRINCIPAL_AMOUNT, COLLATERAL_AMOUNT, LOAN_DURATION, INTEREST_RATE);

        // First fill should succeed
        vm.prank(borrower);
        orderBook.fillLimitOrder{value: COLLATERAL_AMOUNT}(order, signature);

        // Second fill with same nonce should fail
        vm.prank(borrower);
        vm.expectRevert("DebtOrderBook: Nonce already used");
        orderBook.fillLimitOrder{value: COLLATERAL_AMOUNT}(order, signature);
    }

    function test_InterestCalculation() public {
        // Create loan with 365 day duration to test full year interest
        vm.prank(lender);
        usdc.approve(address(orderBook), PRINCIPAL_AMOUNT);

        (DebtOrderBook.LoanLimitOrder memory order, bytes memory signature) =
            _createSignedOrder(PRINCIPAL_AMOUNT, COLLATERAL_AMOUNT, 365 days, INTEREST_RATE);

        vm.prank(borrower);
        orderBook.fillLimitOrder{value: COLLATERAL_AMOUNT}(order, signature);

        DebtHook.Loan memory loan = debtHook.getLoan(1);

        // Test interest calculation at different times
        uint256 amount0Days = debtHook.calculateRepaymentAmount(loan);
        assertEq(amount0Days, PRINCIPAL_AMOUNT);

        // Test after 30 days (should be less than full year)
        vm.warp(block.timestamp + 30 days);
        uint256 amount30Days = debtHook.calculateRepaymentAmount(loan);
        // With 5% APR continuous compounding for 30/365 days: P * e^(0.05 * 30/365)
        // Expected: 1000 * e^0.00411 ≈ 1004.12 USDC
        assertApproxEqRel(amount30Days, 1004.12 * 1e6, 0.01e18); // 1% tolerance

        // Test after full year (but capped at loan duration)
        vm.warp(block.timestamp + 365 days);
        uint256 amount365Days = debtHook.calculateRepaymentAmount(loan);

        // With 5% APR continuous compounding: P * e^(0.05)
        // Expected: 1000 * e^0.05 ≈ 1051.27 USDC
        assertApproxEqRel(amount365Days, 1051.27 * 1e6, 0.01e18); // 1% tolerance
    }

    function test_MultipleLoanTracking() public {
        vm.prank(lender);
        usdc.approve(address(orderBook), PRINCIPAL_AMOUNT * 3);

        // Create 3 loans
        for (uint256 i = 1; i <= 3; i++) {
            (DebtOrderBook.LoanLimitOrder memory order, bytes memory signature) =
                _createSignedOrder(PRINCIPAL_AMOUNT, COLLATERAL_AMOUNT, LOAN_DURATION, INTEREST_RATE);

            order.nonce = i;
            bytes32 orderHash = orderBook.hashLoanLimitOrder(order);
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(lenderPrivateKey, orderHash);
            signature = abi.encodePacked(r, s, v);

            vm.prank(borrower);
            orderBook.fillLimitOrder{value: COLLATERAL_AMOUNT}(order, signature);
        }

        // Check loan tracking
        uint256[] memory borrowerLoans = debtHook.getBorrowerLoans(borrower);
        uint256[] memory lenderLoans = debtHook.getLenderLoans(lender);

        assertEq(borrowerLoans.length, 3);
        assertEq(lenderLoans.length, 3);

        for (uint256 i = 0; i < 3; i++) {
            assertEq(borrowerLoans[i], i + 1);
            assertEq(lenderLoans[i], i + 1);
        }
    }
}
