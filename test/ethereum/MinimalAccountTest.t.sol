// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {MinimalAccount, ECDSA, MessageHashUtils} from "src/ethereum/MinimalAccount.sol";
import {DeployMinimal} from "script/DeployMinimal.s.sol";
import {SendPackedUserOp, PackedUserOperation} from "script/SendPackedUserOp.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {IEntryPoint} from "@eth-infinitism/account-abstraction/interfaces/IEntryPoint.sol";

import {ERC20Mock as ERC20} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// https://youtu.be/mmzkPz71QJs?t=6743

contract MinimalAccountTest is Test {
    using MessageHashUtils for bytes32;

    DeployMinimal accountDeployer;
    MinimalAccount minimalAccount;
    HelperConfig.NetworkConfig config;
    ERC20 usdc;
    SendPackedUserOp sendPackedUserOp;

    address owner = makeAddr("owner");
    address pwner = makeAddr("pwner");
    address randomuser = makeAddr("randomUser");

    uint256 constant AMOUNT = 1e18;

    function setUp() public {
        accountDeployer = new DeployMinimal();
        sendPackedUserOp = new SendPackedUserOp();
        (minimalAccount, config) = accountDeployer.deployMinimalAccount();
        usdc = new ERC20();

        console2.log("Address of test contract : ", address(this));
        console2.log("Address of minimal account owner : ", address(minimalAccount.owner()));
        console2.log("Address of minimal account : ", address(minimalAccount));
        console2.log("Address of usdc : ", address(usdc));
    }

    function test_onwerCanExecuteCommands() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(ERC20.mint.selector, address(minimalAccount), 100e18);
        vm.prank(minimalAccount.owner());
        minimalAccount.execute(dest, value, data);
        assertEq(usdc.balanceOf(address(minimalAccount)), 100e18);
    }

    function test_nonOnwerCannotExecuteCommands() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(ERC20.mint.selector, address(minimalAccount), 100e18);
        vm.prank(pwner);
        vm.expectRevert(abi.encodeWithSelector(MinimalAccount.MinimalAccount__OnlyEntryPointOrOwnerAllowed.selector));
        minimalAccount.execute(dest, value, data);
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        TESTING WITHOUT ENTRY POINT 
    //////////////////////////////////////////////////////////////*/
    function test_ownerSendEthToEOA() public {
        address receiver = makeAddr("receiver");
        vm.deal(minimalAccount.owner(), 100 ether);
        assertEq(minimalAccount.owner().balance, 100 ether);
        assertEq(address(receiver).balance, 0);
        address dest = payable(receiver);
        uint256 value = 2 ether;
        bytes memory data = "";
        vm.prank(minimalAccount.owner());
        minimalAccount.execute{value: value}(dest, value, data);
        assertEq(minimalAccount.owner().balance, 98 ether);
        assertEq(address(receiver).balance, 2 ether);
    }

    function test_ownerSendERC20ToEOA() public {
        address receiver = makeAddr("receiver");
        deal(address(usdc), address(minimalAccount), 100e18);
        assertEq(usdc.balanceOf(address(minimalAccount)), 100e18);
        assertEq(usdc.balanceOf(receiver), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory approveData = abi.encodeWithSignature("approve(address,uint256)", address(receiver), 2e18);
        bytes memory transferData = abi.encodeWithSignature("transfer(address,uint256)", address(receiver), 2e18);

        vm.startPrank(minimalAccount.owner());
        // approve
        minimalAccount.execute(dest, value, approveData);
        // check if the allowance was updated
        assertEq(usdc.allowance(address(minimalAccount), receiver), 2e18);
        minimalAccount.execute(dest, value, transferData);

        // transfer
        vm.stopPrank();
        assertEq(usdc.balanceOf(receiver), 2e18);
        assertEq(usdc.balanceOf(address(minimalAccount)), 98e18);
    }

    /*//////////////////////////////////////////////////////////////
                        TESTING VIA ENTRY POINT 
    //////////////////////////////////////////////////////////////*/

    function test_recoverSignedOperation() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;

        bytes memory data = abi.encodeWithSelector(ERC20.mint.selector, address(minimalAccount), 100e18);
        // data to call entry point
        bytes memory executeCallData = abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, data);
        vm.prank(minimalAccount.owner());

        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generateSignedUserOperation(executeCallData, config, address(minimalAccount));
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(packedUserOp);

        address signer = ECDSA.recover(userOpHash.toEthSignedMessageHash(), packedUserOp.signature);
        console2.log("Signer : ", signer);
        assert(signer == minimalAccount.owner());
    }

    // 1. Sign user ops
    // 2. Call validate userops
    // 3. Assert the return is correct
    function test_validationOfUserOps() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        vm.deal(config.entryPoint, 100e18);
        vm.deal(address(minimalAccount), 100e18);

        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20.mint.selector, address(minimalAccount), AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generateSignedUserOperation(executeCallData, config, address(minimalAccount));
        bytes32 userOperationHash = IEntryPoint(config.entryPoint).getUserOpHash(packedUserOp);
        uint256 missingAccountFunds = 1e18;

        // Act
        vm.prank(config.entryPoint);
        uint256 validationData = minimalAccount.validateUserOp(packedUserOp, userOperationHash, missingAccountFunds);
        assertEq(validationData, 0);
    }

    function test_entryPointCanExecuteCommands() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20.mint.selector, address(minimalAccount), AMOUNT);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, dest, value, functionData);
        PackedUserOperation memory packedUserOp =
            sendPackedUserOp.generateSignedUserOperation(executeCallData, config, address(minimalAccount));
        // bytes32 userOperationHash = IEntryPoint(config.getConfig().entryPoint).getUserOpHash(packedUserOp);

        vm.deal(address(minimalAccount), 1e18);

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;

        // Act
        vm.prank(randomuser);
        IEntryPoint(config.entryPoint).handleOps(ops, payable(randomuser));

        // Assert
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }
}
