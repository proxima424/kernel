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
import {MockERC20} from "./MockERC20.sol";
// test utils
import "forge-std/Test.sol";
import {ERC4337Utils} from "./ERC4337Utils.sol";
// test actions/validators
import "src/validator/ERC165SessionKeyValidator.sol";
import "src/executor/TokenActions.sol";
//interfaces
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {IKernel} from "src/IKernel.sol";
import {INonceManager} from "account-abstraction/interfaces/INonceManager.sol";

using ERC4337Utils for EntryPoint;

contract testERC20 is Test {

    enum Operation {
    Call,
    DelegateCall
    }

    // fork
    uint256 public ethFork;

    // Zerodev specs
    Kernel userSA;
    KernelFactory factory;
    ECDSAKernelFactory ecdsaFactory;
    EntryPoint entryPoint;
    ECDSAValidator validator;

    address owner;
    uint256 ownerKey;
    address public alice;
    address public bob;
    address public proxima424;
    address payable beneficiary;

    MockERC20 public mockToken;

    address public entryPointAdr = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
    address public dai = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    // Address which holds >100M DAI on Ethereum Mainnet
    address public richDAI = 0x40ec5B33f54e0E8A33A975908C5BA1c14e5BbbDf;


    function setUp() public {
        ethFork = vm.createFork("https://eth.llamarpc.com");
        vm.selectFork(ethFork);

        // Init addresses
        (owner, ownerKey) = makeAddrAndKey("owner");
        alice = payable(address(makeAddr("alice")));
        bob = payable(address(makeAddr("bob")));
        proxima424 = payable(address(makeAddr("proxima424")));
        beneficiary = payable(address(makeAddr("beneficiary")));

        // Fund AA specifics
        entryPoint = EntryPoint(payable(entryPointAdr));
        factory = new KernelFactory(entryPoint);
        validator = new ECDSAValidator();
        ecdsaFactory = new ECDSAKernelFactory(factory, validator, entryPoint);
        userSA = Kernel(payable(address(ecdsaFactory.createAccount(owner, 0))));

        mockToken = new MockERC20("mockERC20","mERC20");

        // Fund Addresses
        vm.deal(address(userSA), 1e30);
        vm.deal(alice, 1e30);
        vm.deal(bob, 1e30);
        vm.deal(proxima424, 1e30);
        vm.deal(beneficiary, 1e30);

        // Make non-zero nonce
        vm.startPrank(address(userSA));
        INonceManager(entryPointAdr).incrementNonce(0);
        vm.stopPrank();
    }

    function testERC20TransferCold() public {
        // Fund userSA  with DAI
        vm.startPrank(richDAI);
        IERC20(dai).transfer(address(userSA), 5000);
        vm.stopPrank();

        // Construct a userOp to send a transaction to userSA's execute()
        // Sending 2500 DAI from userSA to proxima424
        uint256 amountOfDAIToSend = 2500;
        bytes memory txnData = abi.encodeWithSignature("transfer(address,uint256)", proxima424,2500);
        bytes memory txnData1 = abi.encodeWithSelector(Kernel.execute.selector,dai,0,txnData,Operation.Call);
        UserOperation memory userOp = entryPoint.fillUserOp(address(userSA), txnData1);
        userOp.signature = abi.encodePacked(bytes4(0x00000000), entryPoint.signUserOpHash(vm, ownerKey, userOp));

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOp;
 
        uint256 prevGas = gasleft();
        console.log("Kernel ETH Mainnet :: Gas consumed in DAI transfer (cold access) is :" );
        entryPoint.handleOps(ops, beneficiary);
        console.log(prevGas-gasleft());
        assertEq(IERC20(dai).balanceOf(proxima424), amountOfDAIToSend);
    }

    function testERC20TransferWarm() public {
        // Fund userSA and proxima424 with DAI
        vm.startPrank(richDAI);
        IERC20(dai).transfer(address(userSA), 5000);
        IERC20(dai).transfer(proxima424, 5000);
        vm.stopPrank();

        // Construct a userOp to send a transaction to userSA's execute()
        // Sending 2500 DAI from userSA to proxima424
        uint256 amountOfDAIToSend = 2500;
        bytes memory txnData = abi.encodeWithSignature("transfer(address,uint256)", proxima424,2500);
        bytes memory txnData1 = abi.encodeWithSelector(Kernel.execute.selector,dai,0,txnData,Operation.Call);
        UserOperation memory userOp = entryPoint.fillUserOp(address(userSA), txnData1);
        userOp.signature = abi.encodePacked(bytes4(0x00000000), entryPoint.signUserOpHash(vm, ownerKey, userOp));

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOp;
 
        uint256 prevGas = gasleft();
        console.log("Kernel ETH Mainnet :: Gas consumed in DAI transfer (warm access) is :" );
        entryPoint.handleOps(ops, beneficiary);
        console.log(prevGas-gasleft());
        assertEq(IERC20(dai).balanceOf(proxima424), amountOfDAIToSend+5000);
    }

    function testERC20ColdApprove() public {
        // Fund userSA with DAI
        vm.startPrank(richDAI);
        IERC20(dai).transfer(address(userSA), 5000);
        vm.stopPrank();

        // Construct userOp to approve 2500 DAI from userSA to proxima424
        uint256 amountOfDAIToApprove = 2500;
        bytes memory txnData = abi.encodeWithSignature("approve(address,uint256)", proxima424, amountOfDAIToApprove);
        bytes memory txnData1 = abi.encodeWithSelector(Kernel.execute.selector, dai,0,txnData,Operation.Call);
        UserOperation memory userOp = entryPoint.fillUserOp(address(userSA), txnData1);
        userOp.signature = abi.encodePacked(bytes4(0x00000000), entryPoint.signUserOpHash(vm, ownerKey, userOp));

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOp;

        console.log("Kernel ETH Mainnet :: Gas consumed in DAI Approval (cold access) is :");
        // Send the userOp to EntryPoint
        uint256 prevGas = gasleft();
        IEntryPoint(entryPointAdr).handleOps(ops, payable(alice));
        console.log(prevGas - gasleft());
        assertEq(IERC20(dai).allowance(address(userSA), proxima424), amountOfDAIToApprove);
    }

    function testERC20WarmApprove() public {
        // Fund userSA with DAI
        vm.startPrank(richDAI);
        IERC20(dai).transfer(address(userSA), 5000);
        vm.stopPrank();

        // To make the allowance mapping storage slot warm,
        // Approve it initially of 2500 DAI
        uint256 amountOfDAIToApprove = 2500;
        vm.startPrank(address(userSA));
        IERC20(dai).approve(proxima424, amountOfDAIToApprove);
        vm.stopPrank();
        assertEq(IERC20(dai).allowance(address(userSA), proxima424), amountOfDAIToApprove);

        // Construct userOp to again approve 2500 DAI from userSA to proxima424
        bytes memory txnData = abi.encodeWithSignature("approve(address,uint256)", proxima424, 2 * amountOfDAIToApprove);
        bytes memory txnData1 = abi.encodeWithSelector(Kernel.execute.selector, dai,0,txnData,Operation.Call);
        UserOperation memory userOp = entryPoint.fillUserOp(address(userSA), txnData1);
        userOp.signature = abi.encodePacked(bytes4(0x00000000), entryPoint.signUserOpHash(vm, ownerKey, userOp));

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOp;

        console.log("Kernel ETH Mainnet :: Gas consumed in DAI Approval (warm access) is :");
        // Send the userOp to EntryPoint
        uint256 prevGas = gasleft();
        IEntryPoint(entryPointAdr).handleOps(ops, payable(alice));
        console.log(prevGas - gasleft());

        assertEq(IERC20(dai).allowance(address(userSA), proxima424), 2 * amountOfDAIToApprove);
    }

    function testERC20MintMockCold() public {
        // Mint MockERC20 with address with zero balance
        uint256 amountToMint = 5000;
        //Construct userOp
        bytes memory txnData = abi.encodeWithSignature("mint(address,uint256)", proxima424, amountToMint);
        bytes memory txnData1 = abi.encodeWithSelector(Kernel.execute.selector, address(mockToken),0,txnData,Operation.Call);
        UserOperation memory userOp = entryPoint.fillUserOp(address(userSA), txnData1);
        userOp.signature = abi.encodePacked(bytes4(0x00000000), entryPoint.signUserOpHash(vm, ownerKey, userOp));

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOp;     

        console.log("Kernel ETH Mainet :: Gas consumed in minting ERC20 (cold mint) is :");
        // Send the userOp to EntryPoint
        uint256 prevGas = gasleft();
        IEntryPoint(entryPointAdr).handleOps(ops, payable(alice));
        console.log(prevGas - gasleft());

        assertEq(mockToken.balanceOf(proxima424), amountToMint);
    }

    function testERC20MintMockWarm() public {
        // Mint some MockToken ERC20 to proxima424 to make the storage slot warm
        uint256 amountToMint = 5000;
        mockToken.mint(proxima424, amountToMint);

        //Construct userOp
        bytes memory txnData = abi.encodeWithSignature("mint(address,uint256)", proxima424, amountToMint);
        bytes memory txnData1 = abi.encodeWithSelector(Kernel.execute.selector, address(mockToken),0,txnData,Operation.Call);
        UserOperation memory userOp = entryPoint.fillUserOp(address(userSA), txnData1);
        userOp.signature = abi.encodePacked(bytes4(0x00000000), entryPoint.signUserOpHash(vm, ownerKey, userOp));

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOp;     

        console.log("Kernel ETH Mainnet :: Gas consumed in minting ERC20 (warm mint) is :");
        // Send the userOp to EntryPoint
        uint256 prevGas = gasleft();
        IEntryPoint(entryPointAdr).handleOps(ops, payable(alice));
        console.log(prevGas - gasleft());
        assertEq(mockToken.balanceOf(proxima424), 2 * amountToMint);
    }
}