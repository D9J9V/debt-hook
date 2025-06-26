// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {USDCPaymasterIntegration} from "../src/USDCPaymasterIntegration.sol";

contract DeployPaymaster is Script {
    // Unichain Sepolia addresses
    address constant USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238; // USDC on Sepolia
    
    // Circle USDC Paymaster on Arbitrum Sepolia (will need to find Unichain address)
    address constant CIRCLE_PAYMASTER = 0x3BA9A96eE3eFf3A69E2B18886AcF52027EFF8966;
    
    function run() external returns (USDCPaymasterIntegration) {
        // Get deployment addresses from environment
        address debtHook = vm.envAddress("DEBT_HOOK_ADDRESS");
        address debtOrderBook = vm.envAddress("DEBT_ORDER_BOOK_ADDRESS");
        
        vm.startBroadcast();
        
        USDCPaymasterIntegration paymaster = new USDCPaymasterIntegration(
            CIRCLE_PAYMASTER,
            USDC,
            debtHook,
            debtOrderBook
        );
        
        vm.stopBroadcast();
        
        // Log deployment
        logDeployment(address(paymaster));
        
        return paymaster;
    }
    
    function logDeployment(address paymaster) internal view {
        string memory chainName = getChainName();
        
        console.log("==========================================");
        console.log("USDC Paymaster Integration Deployed");
        console.log("==========================================");
        console.log("Network:", chainName);
        console.log("Paymaster Integration:", paymaster);
        console.log("Circle Paymaster:", CIRCLE_PAYMASTER);
        console.log("USDC:", USDC);
        console.log("");
        console.log("Next steps:");
        console.log("1. Configure Privy dashboard with paymaster URL");
        console.log("2. Update frontend to use smart wallets");
        console.log("3. Test gasless transactions");
        console.log("==========================================");
    }
    
    function getChainName() internal view returns (string memory) {
        uint256 chainId = block.chainid;
        if (chainId == 1301) return "Unichain Sepolia";
        if (chainId == 421614) return "Arbitrum Sepolia";
        if (chainId == 11155111) return "Sepolia";
        return "Unknown";
    }
}