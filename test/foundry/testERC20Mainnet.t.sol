// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "src/Kernel.sol";
import "src/validator/ECDSAValidator.sol";
import "src/factory/EIP1967Proxy.sol";
import "src/factory/KernelFactory.sol";
import "src/factory/ECDSAKernelFactory.sol";
// test artifacts
import "src/test/TestValidator.sol";
import "src/test/TestExecutor.sol";
import "src/test/TestERC721.sol";
// test utils
import "forge-std/Test.sol";
import {ERC4337Utils} from "./ERC4337Utils.sol";
// test actions/validators
import "src/validator/ERC165SessionKeyValidator.sol";
import "src/executor/TokenActions.sol";

using ERC4337Utils for EntryPoint;

contract testERC20 is Test {

    Kernel kernel;
    KernelFactory factory;
    ECDSAKernelFactory ecdsaFactory;
    EntryPoint entryPoint;
    ECDSAValidator validator;
    address owner;
    uint256 ownerKey;
    address payable beneficiary;

    uint256 a;

    function setUp() public {
        (owner, ownerKey) = makeAddrAndKey("owner");
        entryPoint = new EntryPoint();
        factory = new KernelFactory(entryPoint);

        validator = new ECDSAValidator();
        ecdsaFactory = new ECDSAKernelFactory(factory, validator, entryPoint);

        kernel = Kernel(payable(address(ecdsaFactory.createAccount(owner, 0))));
        vm.deal(address(kernel), 1e30);
        beneficiary = payable(address(makeAddr("beneficiary")));
    }

    function testERC20TransferCold() public {
        
    }
}