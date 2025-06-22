// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {EIP712} from "solady/utils/EIP712.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {IDebtProtocol} from "./interfaces/IDebtProtocol.sol";

contract DebtOrderBook is EIP712 {
    IDebtProtocol public immutable debtProtocol;
    ERC20 public immutable usdc;

    mapping(uint256 => bool) public usedNonces;

    bytes32 private constant _LOAN_LIMIT_ORDER_TYPEHASH =
        keccak256(
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

    event OrderFilled(
        bytes32 indexed orderHash,
        address indexed borrower,
        uint256 principalAmount
    );
    event OrderCancelled(uint256 indexed nonce, address indexed lender);

    constructor(
        address _debtProtocolAddress,
        address _usdcAddress
    ) {
        debtProtocol = IDebtProtocol(_debtProtocolAddress);
        usdc = ERC20(_usdcAddress);
    }
    
    function _domainNameAndVersion() 
        internal 
        pure 
        override 
        returns (string memory name, string memory version) 
    {
        name = "DebtOrderBook";
        version = "1";
    }

    function fillLimitOrder(
        LoanLimitOrder calldata order,
        bytes calldata signature
    ) external payable {
        require(block.timestamp < order.expiry, "DebtOrderBook: Order expired");
        require(
            msg.value >= order.collateralRequired,
            "DebtOrderBook: Insufficient collateral"
        );

        bytes32 orderHash = _hashLoanLimitOrder(order);
        address recoveredLender = ECDSA.recover(
            orderHash,
            signature
        );

        require(
            recoveredLender == order.lender && recoveredLender != address(0),
            "DebtOrderBook: Invalid signature"
        );

        require(!usedNonces[order.nonce], "DebtOrderBook: Nonce already used");
        usedNonces[order.nonce] = true;

        usdc.transferFrom(order.lender, address(this), order.principalAmount);
        usdc.approve(address(debtProtocol), order.principalAmount);

        uint64 duration = order.maturityTimestamp > block.timestamp 
            ? uint64(order.maturityTimestamp - block.timestamp)
            : 0;
            
        debtProtocol.createLoan{value: msg.value}(
            IDebtProtocol.LoanParams({
                lender: order.lender,
                borrower: msg.sender,
                principal: order.principalAmount,
                duration: duration,
                interestRate: uint64(order.interestRateBips)
            })
        );

        emit OrderFilled(orderHash, msg.sender, order.principalAmount);
    }

    // ... (Otras funciones como cancelOrder) ...

    function hashLoanLimitOrder(
        LoanLimitOrder calldata order
    ) public view returns (bytes32) {
        return _hashLoanLimitOrder(order);
    }
    
    function _hashLoanLimitOrder(
        LoanLimitOrder calldata order
    ) internal view returns (bytes32) {
        return
            _hashTypedData(
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
}
