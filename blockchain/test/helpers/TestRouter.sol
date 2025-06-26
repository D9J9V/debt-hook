// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {CurrencySettler} from "v4-core/test/utils/CurrencySettler.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {ModifyLiquidityParams} from "v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";

/// @title TestRouter
/// @notice Helper contract for tests to interact with PoolManager
contract TestRouter is IUnlockCallback {
    using CurrencyLibrary for Currency;
    using CurrencySettler for Currency;

    IPoolManager immutable manager;

    struct CallbackData {
        PoolKey key;
        ModifyLiquidityParams params;
        address sender;
        bool settle;
    }

    constructor(IPoolManager _manager) {
        manager = _manager;
    }

    function modifyLiquidity(PoolKey memory key, ModifyLiquidityParams memory params, bytes memory hookData)
        external
        payable
        returns (BalanceDelta delta)
    {
        delta = abi.decode(manager.unlock(abi.encode(CallbackData(key, params, msg.sender, true))), (BalanceDelta));
    }

    function unlockCallback(bytes calldata data) external override returns (bytes memory) {
        require(msg.sender == address(manager), "Only manager");

        CallbackData memory callbackData = abi.decode(data, (CallbackData));

        (BalanceDelta delta,) = manager.modifyLiquidity(callbackData.key, callbackData.params, "");

        if (callbackData.settle) {
            int128 amount0 = delta.amount0();
            int128 amount1 = delta.amount1();

            if (amount0 < 0) {
                // For ETH (currency0 = address(0)), we send value via settle()
                if (Currency.unwrap(callbackData.key.currency0) == address(0)) {
                    manager.settle{value: uint128(-amount0)}();
                } else {
                    callbackData.key.currency0.settle(manager, callbackData.sender, uint128(-amount0), false);
                }
            }
            if (amount1 < 0) {
                callbackData.key.currency1.settle(manager, callbackData.sender, uint128(-amount1), false);
            }
            if (amount0 > 0) {
                callbackData.key.currency0.take(manager, callbackData.sender, uint128(amount0), false);
            }
            if (amount1 > 0) {
                callbackData.key.currency1.take(manager, callbackData.sender, uint128(amount1), false);
            }
        }

        return abi.encode(delta);
    }

    receive() external payable {}
}
