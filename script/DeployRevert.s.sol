// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {SimpleRevertExample} from "../src/ethereum/SimpleRevert.sol";

import {HelperConfig} from "./HelperConfig.s.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract DeployRevert is Script {
    function run() public {
        uint256 deployerKey;
        address deployer;
        string memory mnemonic = vm.envString("MNEMONIC");
        console2.log(mnemonic);
        (deployer, deployerKey) = deriveRememberKey(mnemonic, 0);

        HelperConfig helperConfig = new HelperConfig();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        vm.startBroadcast(config.account);
        SimpleRevertExample revertex = new SimpleRevertExample();
        console2.log("Revert example address : ", address(revertex));
        revertex.withdraw(2 ether);
        vm.stopBroadcast();
    }
}

//  Sourcify
// forge script script/DeployRevert.s.sol --rpc-url buildbear --verifier sourcify --verify --verifier-url https://rpc.buildbear.io/verify/sourcify/server/religious-sunfire-14b26c72 --broadcast

// Etherscan
// forge script script/DeployRevert.s.sol --rpc-url buildbear --etherscan-api-key "verifyContract" --verifier-url "https://rpc.buildbear.io/verify/etherscan/uzair"  -vvvv --broadcast --verify

/*
Etherscan - after contract deployment
forge verify-contract --flatten --watch --constructor-args $(cast abi-encode "constructor(address,address)" "0x348ED5965e6aF8cc1E2Ff4739F670165194FCe4e" "0x0000000071727De22E5E9d8BAf0edAc6f37da032") 0xFB4D477813df094d260EC2Ff31c6d5076aC1f250 MinimalAccount --etherscan-api-key "verifyContract" --verifier-url "https://rpc.buildbear.io/verify/etherscan/uzair" 
*/
