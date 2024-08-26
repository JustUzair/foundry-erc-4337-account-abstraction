// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MinimalAccount} from "src/ethereum/MinimalAccount.sol";
import {DeployMinimal} from "script/DeployMinimal.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {ERC20Mock as ERC20} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract MinimalAccountTest is Test {
    DeployMinimal accountDeployer;
    MinimalAccount minimalAccount;
    HelperConfig.NetworkConfig config;
    ERC20 usdc;
    address owner = makeAddr("owner");
    address pwner = makeAddr("pwner");

    function setUp() public {
        accountDeployer = new DeployMinimal();
        (minimalAccount, config) = accountDeployer.deployMinimalAccount();
        usdc = new ERC20();
    }

    function _simulateSignatureFromSender(address sender, bytes memory data) private returns (bytes memory) {
        bytes32 hash = keccak256(data);
        return abi.encodePacked(hash, sender);
    }

    function testOnwerCanExecuteCommands() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(ERC20.mint.selector, address(minimalAccount), 100e18);
        vm.prank(minimalAccount.owner());
        minimalAccount.execute(dest, value, data);
        assertEq(usdc.balanceOf(address(minimalAccount)), 100e18);
    }

    function testNonOnwerCannotExecuteCommands() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory data = abi.encodeWithSelector(ERC20.mint.selector, address(minimalAccount), 100e18);
        vm.prank(pwner);
        vm.expectRevert(abi.encodeWithSelector(MinimalAccount.MinimalAccount__OnlyEntryPointOrOwnerAllowed.selector));
        minimalAccount.execute(dest, value, data);
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
    }
}
