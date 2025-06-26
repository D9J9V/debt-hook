// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {DebtOrderBook} from "../src/DebtOrderBook.sol";

contract UpdateOrderBook is Script {
    address constant NEW_DEBT_HOOK = 0x49e39eFDE0C93F6601d84cb5C6D24c1B23eB00C8;
    address constant USDC = 0x73CFC55f831b5DD6E5Ee4CEF02E8c05be3F069F6;
    address constant SERVICE_MANAGER = 0x3333Bc77EdF180D81ff911d439F02Db9e34e8603;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console.log("Deploying new DebtOrderBook...");
        console.log("DebtHook:", NEW_DEBT_HOOK);
        console.log("USDC:", USDC);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy new OrderBook pointing to new DebtHook
        DebtOrderBook orderBook = new DebtOrderBook(NEW_DEBT_HOOK, USDC);
        console.log("New DebtOrderBook deployed:", address(orderBook));
        
        // Set ServiceManager
        orderBook.setServiceManager(SERVICE_MANAGER);
        console.log("ServiceManager set:", SERVICE_MANAGER);
        
        vm.stopBroadcast();
        
        console.log("\nDEPLOYMENT COMPLETE!");
        console.log("DebtOrderBook:", address(orderBook));
    }
}
