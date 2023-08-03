// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

// core
import "src/Kernel.sol";
import "src/validator/ECDSAValidator.sol";
import "src/factory/EIP1967Proxy.sol";
import "src/factory/KernelFactory.sol";
import "src/factory/ECDSAKernelFactory.sol";

// test actions/validators
import "src/validator/ERC165SessionKeyValidator.sol";
import "src/executor/TokenActions.sol";

using ERC4337Utils for EntryPoint;

contract testERC20Kernel is Test {
    uint256 a;

    function setUp() public {
        a++;
    }
}