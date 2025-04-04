// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {MinimalAccount} from "../src/ethereum/MinimalAccount.sol";
import {PackedUserOperation} from "@eth-infinitism/account-abstraction/interfaces/PackedUserOperation.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {IEntryPoint} from "@eth-infinitism/account-abstraction/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {console2} from "forge-std/console2.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract SendPackedUserOp is Script {
    using MessageHashUtils for bytes32;

    uint256 constant VERIFICATION_GAS_LIMIT = 16777216;
    uint256 constant CALL_GAS_LIMIT = VERIFICATION_GAS_LIMIT;
    uint256 constant MAX_FEE_PER_GAS = 256;
    uint256 constant MAX_PRIORITY_FEE_PER_GAS = MAX_FEE_PER_GAS;

    function run() public {
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address dest = address(usdc);
        uint256 value = 0;
        address receiver = 0xA72e562f24515C060F36A2DA07e0442899D39d2c;
        bytes memory approveData = abi.encodeWithSignature("approve(address,uint256)", address(receiver), UINT256_MAX);
        bytes memory transferData = abi.encodeWithSignature("transfer(address,uint256)", address(receiver), 2e6);
        MinimalAccount minimalAccount = MinimalAccount(payable(0x37cBB2703D0312Ae2904c2FA131970823B7b1cd7));

        uint256 deployerKey;
        address deployer;
        string memory mnemonic = vm.envString("MNEMONIC");
        console2.log(mnemonic);
        (deployer, deployerKey) = deriveRememberKey(mnemonic, 0);

        HelperConfig helperConfig = new HelperConfig();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        // vm.startBroadcast(deployer);
        // IERC20(usdc).approve(address(minimalAccount), UINT256_MAX);
        // IERC20(usdc).transferFrom(config.account, address(minimalAccount), 10e6);
        // vm.stopBroadcast();
        vm.startBroadcast(deployer);

        // approve
        minimalAccount.execute(dest, value, approveData);
        // check if the allowance was updated
        minimalAccount.execute(dest, value, transferData);
        vm.stopBroadcast();
    }

    function generateSignedUserOperation(
        bytes memory callData,
        HelperConfig.NetworkConfig memory config,
        address minimalAccount
    ) public view returns (PackedUserOperation memory userOp) {
        // 1. Generate signed data
        uint256 nonce = vm.getNonce(minimalAccount) - 1;
        userOp = _generateSignedData(callData, minimalAccount, nonce);
        // 2. Get the userOp Hash
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOp);
        // 3. Sign data, return signed data
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_TEST_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

        if (block.chainid == 31337) {
            (v, r, s) = vm.sign(ANVIL_TEST_PRIVATE_KEY, digest);
        } else {
            (v, r, s) = vm.sign(minimalAccount, digest);
        }
        userOp.signature = abi.encodePacked(r, s, v);
        return userOp;
    }

    function _generateSignedData(bytes memory callData, address sender, uint256 nonce)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"",
            callData: callData,
            /**
             * @explanation: accountGasLimit calculation using Chisel
             *      ➜ VERIFICATION_GAS_LIMIT
             *                 Type: uint256
             *                 ├ Hex: 0x1000000
             *                 ├ Hex (full word): 0x1000000
             *                 └ Decimal: 16777216
             *                 ➜ CALL_GAS_LIMIT
             *                 Type: uint256
             *                 ├ Hex: 0x1000000
             *                 ├ Hex (full word): 0x1000000
             *                 └ Decimal: 16777216
             *                 ➜ bytes32(uint256(VERIFICATION_GAS_LIMIT) << 128 | CALL_GAS_LIMIT)
             *                 Type: bytes32
             *                 └ Data: 0x0000000000000000000000000100000000000000000000000000000001000000
             */
            accountGasLimits: bytes32(uint256(VERIFICATION_GAS_LIMIT) << 128 | CALL_GAS_LIMIT),
            preVerificationGas: VERIFICATION_GAS_LIMIT,
            /**
             * @explanation: gasFees calculation using Chisel
             *                 ➜ MAX_FEE_PER_GAS
             *                 Type: uint256
             *                 ├ Hex: 0x100
             *                 ├ Hex (full word): 0x100
             *                 └ Decimal: 256
             *                 ➜ MAX_PRIORITY_FEE_PER_GAS
             *                 Type: uint256
             *                 ├ Hex: 0x100
             *                 ├ Hex (full word): 0x100
             *                 └ Decimal: 256
             *                 ➜ bytes32(uint256(MAX_PRIORITY_FEE_PER_GAS) << 128 | MAX_FEE_PER_GAS)
             *                 Type: bytes32
             *                 └ Data: 0x0000000000000000000000000000010000000000000000000000000000000100
             */
            gasFees: bytes32(uint256(MAX_PRIORITY_FEE_PER_GAS) << 128 | MAX_FEE_PER_GAS),
            paymasterAndData: hex"",
            signature: hex""
        });
    }
}
