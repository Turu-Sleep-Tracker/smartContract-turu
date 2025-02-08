// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/SleepNFT.sol";

// Mock zkTLS Verifier untuk testing
contract MockZkTLSVerifier is IZkTLSVerifier {
    function verifyProof(
        bytes calldata /*proof*/,
        bytes32 /*root*/,
        bytes32[] calldata /*publicInputs*/
    ) external pure override returns (bool) {
        return true; // Selalu return true untuk testing
    }
}

contract SleepNFTTest is Test {
    SleepNFT nft;
    MockZkTLSVerifier verifier;
    address user = address(1);
    uint256 BASE_PRICE = 0.05 ether;
    uint256 DECAY_RATE = 0.001 ether;

    function setUp() public {
        verifier = new MockZkTLSVerifier();
        nft = new SleepNFT(address(verifier), BASE_PRICE, DECAY_RATE);
        vm.deal(user, 10 ether);
    }

    // Test minting NFT dengan data valid
    function testMintNFT() public {
        vm.startPrank(user);

        uint256 startTime = block.timestamp - 8 hours;
        uint256 expectedPrice = BASE_PRICE - (DECAY_RATE * (block.timestamp - startTime));

        nft.mintSleepNFT{value: expectedPrice}(
            "",
            bytes32(0),
            new bytes32[](0),
            60,  // hrv
            70,  // rhr
            180, // deepSleep
            240, // lightSleep
            120, // remSleep
            startTime,
            block.timestamp,
            480, // duration (8 jam)
            "ipfs://test"
        );

        // Verifikasi NFT
        assertEq(nft.ownerOf(0), user);
        SleepNFT.SleepData memory data = nft.getSleepData(0);
        assertEq(data.hrv, 60);
        assertEq(data.duration, 480);
    }

    // Test harga NFT dengan VRGDA
    function testPriceCalculation() public {
        uint256 elapsedTime = 3600; // 1 jam
        uint256 expectedPrice = BASE_PRICE - (DECAY_RATE * elapsedTime);
        assertEq(nft.calculatePrice(elapsedTime), expectedPrice);
    }

    // Test pembayaran kurang
    function testInsufficientPayment() public {
        vm.startPrank(user);
        vm.expectRevert("Insufficient payment");
        nft.mintSleepNFT{value: 0.01 ether}(
            "",
            bytes32(0),
            new bytes32[](0),
            60, 70, 180, 240, 120,
            block.timestamp - 8 hours,
            block.timestamp,
            480,
            "ipfs://test"
        );
    }

    // Test proof zkTLS invalid
    function testInvalidZkTLSProof() public {
        // Mock verifier yang return false
        MockZkTLSVerifier invalidVerifier = new MockZkTLSVerifier();
        vm.mockCall(
            address(invalidVerifier),
            abi.encodeWithSelector(MockZkTLSVerifier.verifyProof.selector),
            abi.encode(false)
        );

        SleepNFT invalidNFT = new SleepNFT(address(invalidVerifier), BASE_PRICE, DECAY_RATE);
        vm.startPrank(user);
        vm.expectRevert("Invalid zkTLS proof");
        invalidNFT.mintSleepNFT{value: BASE_PRICE}(
            "",
            bytes32(0),
            new bytes32[](0),
            60, 70, 180, 240, 120,
            block.timestamp - 8 hours,
            block.timestamp,
            480,
            "ipfs://test"
        );
    }
}