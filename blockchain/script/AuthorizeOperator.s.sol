// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

interface IDebtHookAuth {
    function authorizeOperator(address operator, bool authorized) external;
    function authorizedOperators(address operator) external view returns (bool);
}

contract AuthorizeOperator is Script {
    address constant DEBT_HOOK = 0x0C075a62FD69EA6Db1F65566911C4f1D221e40c8;
    address constant OPERATOR = 0x2f131a86C5CB54685f0E940B920c54E152a44B02;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Authorizing operator from:", deployer);
        console.log("DebtHook:", DEBT_HOOK);
        console.log("Operator to authorize:", OPERATOR);
        
        vm.startBroadcast(deployerPrivateKey);
        
        IDebtHookAuth debtHook = IDebtHookAuth(DEBT_HOOK);
        
        // Try to authorize the operator
        console.log("Calling authorizeOperator...");
        try debtHook.authorizeOperator(OPERATOR, true) {
            console.log("SUCCESS: Operator authorized successfully!");
            
            // Verify authorization
            bool isAuthorized = debtHook.authorizedOperators(OPERATOR);
            console.log("Authorization verified:", isAuthorized);
        } catch Error(string memory reason) {
            console.log("ERROR: Authorization failed:", reason);
            console.log("This likely means the DebtHook hasn't been upgraded yet.");
        } catch {
            console.log("ERROR: Authorization failed with unknown error");
            console.log("The contract may not have the authorization functions.");
        }
        
        vm.stopBroadcast();
    }
}
