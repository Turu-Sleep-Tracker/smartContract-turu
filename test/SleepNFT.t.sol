// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/SleepNFT.sol";
import "../src/SleepToken.sol";

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
    SleepToken token;
    MockZkTLSVerifier verifier;
    address user = address(1);
    uint256 BASE_PRICE = 0.05 ether;
    uint256 DECAY_RATE = 0.001 ether;

    function setUp() public {
        // Warp block.timestamp ke nilai yang cukup tinggi agar pengurangan 8 hours tidak underflow
        vm.warp(1_000_000);

        verifier = new MockZkTLSVerifier();
        nft = new SleepNFT(address(verifier), BASE_PRICE, DECAY_RATE);
        vm.deal(user, 10 ether);

        // Deploy SleepToken dan transfer kepemilikan ke kontrak NFT sehingga NFT bisa mint token reward
        token = new SleepToken();
        token.transferOwnership(address(nft));
        nft.setRewardToken(address(token));
    }

    // Test minting NFT dengan data tidur dan perhitungan reward
    function testMintNFTWithReward() public {
        vm.startPrank(user);

        uint256 startTime = block.timestamp - 8 hours;
        uint256 elapsedTime = block.timestamp - startTime;
        uint256 expectedPrice = BASE_PRICE - (DECAY_RATE * (elapsedTime / 3600));
        // Contoh: untuk 8 jam, expectedPrice = 0.05 ether - (0.001 ether * 8) = 0.042 ether

        nft.mintSleepNFT{value: expectedPrice}(
            "",
            bytes32(0),
            new bytes32[](0),
            60,   // hrv
            70,   // rhr
            240,  // deepSleep (50% dari 480, sehingga kualitas baik)
            180,  // lightSleep
            60,   // remSleep
            startTime,
            block.timestamp,
            480,  // duration (8 jam dalam menit)
            "ipfs://test"
        );

        // Verifikasi NFT telah diterbitkan
        assertEq(nft.ownerOf(0), user);
        SleepNFT.SleepData memory data = nft.getSleepData(0);
        // Karena tidur berkualitas dan ini adalah sesi pertama, consecutiveGoodSleepCount = 1
        // Reward = 10 * 1e18 * 1 = 10e18
        assertEq(data.rewardAmount, 10 * 1e18);
        assertEq(data.rewardClaimed, false);
        vm.stopPrank();
    }

    // Test klaim reward token
    function testClaimReward() public {
        vm.startPrank(user);
        uint256 startTime = block.timestamp - 8 hours;
        uint256 elapsedTime = block.timestamp - startTime;
        uint256 expectedPrice = BASE_PRICE - (DECAY_RATE * (elapsedTime / 3600));

        // Mint NFT
        nft.mintSleepNFT{value: expectedPrice}(
            "",
            bytes32(0),
            new bytes32[](0),
            60,
            70,
            240,
            180,
            60,
            startTime,
            block.timestamp,
            480,
            "ipfs://test"
        );

        // Sebelum claim, balance token harus 0
        assertEq(token.balanceOf(user), 0);

        // Claim reward untuk tokenId 0
        nft.claimReward(0);

        // Setelah klaim, balance token harus bertambah sebesar 10e18
        assertEq(token.balanceOf(user), 10 * 1e18);

        // Mencoba claim kembali harus gagal
        vm.expectRevert("Reward already claimed");
        nft.claimReward(0);
        vm.stopPrank();
    }

    // Test minting gagal karena pembayaran tidak cukup
    function testInsufficientPayment() public {
        vm.startPrank(user);
        vm.expectRevert("Insufficient payment");
        nft.mintSleepNFT{value: 0.01 ether}(
            "",
            bytes32(0),
            new bytes32[](0),
            60, 70, 240, 180, 60,
            block.timestamp - 8 hours,
            block.timestamp,
            480,
            "ipfs://test"
        );
        vm.stopPrank();
    }

    // Test minting gagal karena zkTLS proof tidak valid
    function testInvalidZkTLSProof() public {
        // Buat verifier mock yang return false
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
            60, 70, 240, 180, 60,
            block.timestamp - 8 hours,
            block.timestamp,
            480,
            "ipfs://test"
        );
        vm.stopPrank();
    }
}
