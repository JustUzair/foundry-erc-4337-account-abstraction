// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IAccount} from "@eth-infinitism/account-abstraction/interfaces/IAccount.sol";
import {PackedUserOperation} from "@eth-infinitism/account-abstraction/interfaces/PackedUserOperation.sol";
import {UserOperationLib} from "@eth-infinitism/account-abstraction/core/UserOperationLib.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IEntryPoint} from "@eth-infinitism/account-abstraction/interfaces/IEntryPoint.sol";

contract MinimalAccount is IAccount, Ownable {
    /*//////////////////////////////////////////////////////////////
                                ERRORS 
    //////////////////////////////////////////////////////////////*/

    error MinimalAccount__OnlyEntryPointAllowed();
    error MinimalAccount__OnlyEntryPointOrOwnerAllowed();
    error MinimalAccount__CallFailed(bytes);

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event FundsReceived(address indexed sender, uint256 value);
    /*//////////////////////////////////////////////////////////////
                                CONSTANTS 
    //////////////////////////////////////////////////////////////*/

    uint256 public constant SIG_VALIDATION_SUCCESS = 1;
    uint256 public constant SIG_VALIDATION_FAILED = 0;

    /*//////////////////////////////////////////////////////////////
                                IMMUTABLES 
    //////////////////////////////////////////////////////////////*/

    IEntryPoint private immutable i_entryPoint;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES 
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS 
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Modifier to check if the caller is the entry point or the owner
     */
    modifier onlyEntryPointOrOwner() {
        if (msg.sender != address(i_entryPoint) && msg.sender != owner()) {
            revert MinimalAccount__OnlyEntryPointOrOwnerAllowed();
        }
        _;
    }

    /**
     * @dev Modifier to check if the caller is the entry point
     */
    modifier onlyEntryPoint() {
        if (msg.sender != address(i_entryPoint)) {
            revert MinimalAccount__OnlyEntryPointAllowed();
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                 FUNCTIONS 
    //////////////////////////////////////////////////////////////*/

    /**
     * @param _owner - Owner of the account
     * @param _entryPoint - Address of the entry point contract
     */
    constructor(address _owner, address _entryPoint) Ownable(_owner) {
        i_entryPoint = IEntryPoint(_entryPoint);
    }

    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                        EXTERNAL & PUBLIC FUNCTIONS 
    //////////////////////////////////////////////////////////////*/

    /**
     * function that validates user operation
     * @param userOp                -  The struct that stores data such as sender, nonce, gasFees, signature, etc.
     * @param userOpHash            -  The hash of the user operation
     * @param missingAccountFunds   -  The amount of funds missing in the account
     */
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        returns (uint256 validationData)
    {
        validationData = _validateSignature(userOp, userOpHash);
        _payPrefund(missingAccountFunds);
    }

    function execute(address dest, uint256 value, bytes calldata functionData) external payable onlyEntryPointOrOwner {
        (bool success, bytes memory result) = payable(dest).call{value: value}(functionData);
        if (!success) {
            revert MinimalAccount__CallFailed(result);
        }
    }

    /**
     * @dev Function to set owner of contract
     * @param _newOwner - new owner address
     */
    function setOwner(address _newOwner) public onlyOwner {
        transferOwnership(_newOwner);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS 
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Function to validate the signature of the user operation
     * @dev Signature used EIP-191 signature format
     * @param userOp - The struct that stores data such as sender, nonce, gasFees, signature, etc.
     * @param userOpHash -  The hash of the user operation
     */
    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        returns (uint256 validationData)
    {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);
        if (signer != owner()) {
            return SIG_VALIDATION_FAILED;
        }
        return SIG_VALIDATION_SUCCESS;
    }

    /**
     * @dev Function to pay the prefund to the account
     * @param missingAccountFunds - The amount of funds missing in the account
     */
    function _payPrefund(uint256 missingAccountFunds) internal {
        if (missingAccountFunds > 0) {
            (bool success,) = payable(msg.sender).call{value: missingAccountFunds, gas: gasleft()}("");
            require(success, "MA: Prefund failed");
        }
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW & GETTER FUNCTIONS 
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Function to get owner of contract
     */
    function getOwner() public view returns (address) {
        return owner();
    }
}
