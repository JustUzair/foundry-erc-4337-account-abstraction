// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {DeployMinimal} from "script/DeployMinimal.s.sol";
import {SendPackedUserOp} from "script/SendPackedUserOp.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock as ERC20} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// https://youtu.be/mmzkPz71QJs?t=5690

contract MinimalAccountTest is Test {
    DeployMinimal accountDeployer;
    MinimalAccount minimalAccount;
    HelperConfig.NetworkConfig config;
    ERC20 usdc;
    SendPackedUserOp sendPackedUserOp;

    address owner = makeAddr("owner");
    address pwner = makeAddr("pwner");

    function setUp() public {
        accountDeployer = new DeployMinimal();
        sendPackedUserOp = new SendPackedUserOp();
        (minimalAccount, config) = accountDeployer.deployMinimalAccount();
        usdc = new ERC20();
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
}
