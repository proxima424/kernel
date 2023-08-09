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
import {MockERC721} from "../MockERC721.sol";
// test utils
import "forge-std/Test.sol";
import {ERC4337Utils} from "../ERC4337Utils.sol";
// test actions/validators
import "src/validator/ERC165SessionKeyValidator.sol";
import "src/executor/TokenActions.sol";
//interfaces
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {IKernel} from "src/IKernel.sol";
import {INonceManager} from "account-abstraction/interfaces/INonceManager.sol";

using ERC4337Utils for EntryPoint;


contract testERC721 is Test {
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

    MockERC721 public mockToken;

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

        mockToken = new MockERC721("mockERC721","mERC721");

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

    function testERC721TransferWarm() public {
        // Mint userSA an NFT with tokeniD 0
        mockToken.mint(address(userSA), 0);
        mockToken.mint(proxima424,1);

        // Construct userOp to send ERC721from userSA to proxima424
        bytes memory txnData = abi.encodeWithSignature("transfer(address,uint256)", proxima424, 0);
        bytes memory txnData1 = abi.encodeWithSelector(Kernel.execute.selector,address(mockToken),0,txnData,Operation.Call);
        UserOperation memory userOp = entryPoint.fillUserOp(address(userSA), txnData1);
        userOp.signature = abi.encodePacked(bytes4(0x00000000), entryPoint.signUserOpHash(vm, ownerKey, userOp));

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOp;

        console.log("Kernel ETH Mainnet :: Gas consumed in NFT transfer (warm access) is :");
        // Send the userOp to EntryPoint
        uint256 prevGas = gasleft();
        IEntryPoint(entryPointAdr).handleOps(ops, payable(alice));
        console.log(prevGas - gasleft());
        // INVARIANT := NFT tokenId 0 transferred from userSA to proxima424
        assertEq(mockToken.ownerOf(0), proxima424);   

    }
    function testERC721TransferCold() public {
        // Mint userSA an NFT with tokeniD 0
        mockToken.mint(address(userSA), 0);

        // Construct userOp to send ERC721from userSA to proxima424
        bytes memory txnData = abi.encodeWithSignature("transfer(address,uint256)", proxima424, 0);
        bytes memory txnData1 = abi.encodeWithSelector(Kernel.execute.selector,address(mockToken),0,txnData,Operation.Call);
        UserOperation memory userOp = entryPoint.fillUserOp(address(userSA), txnData1);
        userOp.signature = abi.encodePacked(bytes4(0x00000000), entryPoint.signUserOpHash(vm, ownerKey, userOp));

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOp;

        console.log("Kernel ETH Mainnet :: Gas consumed in NFT transfer (cold access) is :");
        // Send the userOp to EntryPoint
        uint256 prevGas = gasleft();
        IEntryPoint(entryPointAdr).handleOps(ops, payable(alice));
        console.log(prevGas - gasleft());
        // INVARIANT := NFT tokenId 0 transferred from userSA to proxima424
        assertEq(mockToken.ownerOf(0), proxima424);
    }

    function testERC721MintCold() public {

        // Construct userOp to mint ERC721 to userSA
        bytes memory txnData = abi.encodeWithSignature("mint(address,uint256)", address(userSA), 0);
        bytes memory txnData1 = abi.encodeWithSelector(Kernel.execute.selector,address(mockToken),0,txnData,Operation.Call);
        UserOperation memory userOp = entryPoint.fillUserOp(address(userSA), txnData1);
        userOp.signature = abi.encodePacked(bytes4(0x00000000), entryPoint.signUserOpHash(vm, ownerKey, userOp));

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOp;

        console.log("Kernel ETH Mainnet :: Gas consumed in NFT Mint (cold access) is :");
        // Send the userOp to EntryPoint
        uint256 prevGas = gasleft();
        IEntryPoint(entryPointAdr).handleOps(ops, payable(alice));
        console.log(prevGas - gasleft());
        // INVARIANT := NFT tokenId 0 minted to userSA
        assertEq(mockToken.ownerOf(0), address(userSA));   
        
    }

    function testERC721MintWarm() public {
        mockToken.mint(address(userSA),0);

        // Construct userOp to mint ERC721 to userSA
        bytes memory txnData = abi.encodeWithSignature("mint(address,uint256)", address(userSA), 1);
        bytes memory txnData1 = abi.encodeWithSelector(Kernel.execute.selector,address(mockToken),0,txnData,Operation.Call);
        UserOperation memory userOp = entryPoint.fillUserOp(address(userSA), txnData1);
        userOp.signature = abi.encodePacked(bytes4(0x00000000), entryPoint.signUserOpHash(vm, ownerKey, userOp));

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOp;

        console.log("Kernel ETH Mainnet :: Gas consumed in NFT Mint (warm access) is :");
        // Send the userOp to EntryPoint
        uint256 prevGas = gasleft();
        IEntryPoint(entryPointAdr).handleOps(ops, payable(alice));
        console.log(prevGas - gasleft());
        // INVARIANT := NFT tokenId 0 minted to userSA
        assertEq(mockToken.ownerOf(1), address(userSA));   
    }

    function testERC721ApproveCold() public {
        // Mint NFT to userSA 
        mockToken.mint(address(userSA), 0);

        // Construct userOp to approve Alice of ERC721 tokenId 0
        bytes memory txnData = abi.encodeWithSignature("approve(address,uint256)", alice, 0);
        bytes memory txnData1 = abi.encodeWithSelector(Kernel.execute.selector,address(mockToken),0,txnData,Operation.Call);
        UserOperation memory userOp = entryPoint.fillUserOp(address(userSA), txnData1);
        userOp.signature = abi.encodePacked(bytes4(0x00000000), entryPoint.signUserOpHash(vm, ownerKey, userOp));

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOp;

        console.log("Kernel ETH Mainnet :: Gas consumed in NFT Approval (warm access) is :");
        // Send the userOp to EntryPoint
        uint256 prevGas = gasleft();
        IEntryPoint(entryPointAdr).handleOps(ops, payable(alice));
        console.log(prevGas - gasleft());
        // NFT with tokenId 0 is minted to userSA
        assertEq(mockToken.getApproved(0), alice);
    }
    function testERC721ApproveWarm() public {
        // Mint NFT to userSA and approve proxima424
        // To make the _tokenApproval[0] storage slot warm
        mockToken.mint(address(userSA), 0);
        vm.startPrank(address(userSA));
        mockToken.approve(proxima424, 0);
        vm.stopPrank();
        assertEq(mockToken.getApproved(0), proxima424);

        // Construct userOp to approve Alice of ERC721 tokenId 0
        bytes memory txnData = abi.encodeWithSignature("approve(address,uint256)", alice, 0);
        bytes memory txnData1 = abi.encodeWithSelector(Kernel.execute.selector,address(mockToken),0,txnData,Operation.Call);
        UserOperation memory userOp = entryPoint.fillUserOp(address(userSA), txnData1);
        userOp.signature = abi.encodePacked(bytes4(0x00000000), entryPoint.signUserOpHash(vm, ownerKey, userOp));

        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = userOp;

        console.log("Kernel ETH Mainnet :: Gas consumed in NFT Approval (warm access) is :");
        // Send the userOp to EntryPoint
        uint256 prevGas = gasleft();
        IEntryPoint(entryPointAdr).handleOps(ops, payable(alice));
        console.log(prevGas - gasleft());
        // NFT with tokenId 0 is minted to userSA
        assertEq(mockToken.getApproved(0), alice);
    }
    


}