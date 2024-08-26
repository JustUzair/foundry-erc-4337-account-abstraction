// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {PackedUserOperation} from "@eth-infinitism/account-abstraction/interfaces/PackedUserOperation.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {IEntryPoint} from "@eth-infinitism/account-abstraction/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract SendPackedUserOp is Script {
    using MessageHashUtils for bytes32;

    uint256 constant VERIFICATION_GAS_LIMIT = 16777216;
    uint256 constant CALL_GAS_LIMIT = VERIFICATION_GAS_LIMIT;
    uint256 constant MAX_FEE_PER_GAS = 256;
    uint256 constant MAX_PRIORITY_FEE_PER_GAS = MAX_FEE_PER_GAS;

    function run() public {}

    function generateSignedUserOperation(bytes memory callData, HelperConfig.NetworkConfig memory config)
        public
        view
        returns (PackedUserOperation memory userOp)
    {
        // 1. Generate signed data
        uint256 nonce = vm.getNonce(config.account);
        userOp = _generateSignedData(callData, config.account, nonce);
        // 2. Get the userOp Hash
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOp);
        // 3. Sign data, return signed data
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(userOpHash);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(config.account, digest);
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
