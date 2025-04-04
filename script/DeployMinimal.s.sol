// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {MinimalAccount} from "../src/ethereum/MinimalAccount.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract DeployMinimal is Script {
    function run() public {
        deployMinimalAccount();
    }

    function deployMinimalAccount() public returns (MinimalAccount, HelperConfig.NetworkConfig memory) {
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address dest = address(usdc);
        uint256 value = 1e18;
        address receiver = 0xA72e562f24515C060F36A2DA07e0442899D39d2c;
        bytes memory callData = abi.encodeWithSignature("call(bytes memory)", "");

        uint256 deployerKey;
        address deployer;
        string memory mnemonic = vm.envString("MNEMONIC");
        console2.log(mnemonic);
        (deployer, deployerKey) = deriveRememberKey(mnemonic, 0);

        HelperConfig helperConfig = new HelperConfig();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        vm.startBroadcast(config.account);
        MinimalAccount minimalAccount = new MinimalAccount(config.account, config.entryPoint);
        // minimalAccount.transferOwnership(msg.sender);
        minimalAccount.execute{value: 1e18}(receiver, value, callData);

        // transfer
        vm.stopBroadcast();
        return (minimalAccount, config);
    }
}

// forge script script/DeployMinimal.s.sol --rpc-url buildbear --verifier sourcify --verify --verifier-url https://rpc.buildbear.io/verify/sourcify/server/yearning-vision-3f3e4e09
// forge script script/DeployMinimal.s.sol --rpc-url buildbear --etherscan-api-key "verifyContract" --verifier-url "https://rpc.buildbear.io/verify/etherscan/yearning-vision-3f3e4e09" -vvvv --broadcast --verify --slow
