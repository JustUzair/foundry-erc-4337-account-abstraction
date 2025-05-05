// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SimpleRevertExample {
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    function withdraw(uint256 amount) public {
        if (msg.sender != owner) {
            revert("Not the contract owner");
        }

        if (amount > 1 ether) {
            revert("Amount exceeds limit");
        }

        owner = msg.sender;
    }
}
