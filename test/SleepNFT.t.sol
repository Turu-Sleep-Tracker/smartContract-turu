// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/SleepNFT.sol";
import "../src/SleepToken.sol";
import "../src/mocks/ZkTlsVerifierMock.sol";
import "../src/libraries/SleepDataLib.sol";

contract SleepNFTTest is Test {
    SleepNFT public sleepNFT;
    SleepToken public sleepToken;
    ZkTlsVerifierMock public verifierMock;
    address public addr1 = address(0x1);

    // Harga NFT sesuai dengan deployment, misalnya 0.01 ether
    uint256 nftPrice = 0.01 ether;

    function setUp() public {
        // Set block.timestamp ke nilai nonzero agar perhitungan waktu tidak underflow
        vm.warp(10000);

        // Deploy mock verifier
        verifierMock = new ZkTlsVerifierMock();

        // Deploy SleepToken
        sleepToken = new SleepToken();

        // Deploy SleepNFT dengan alamat verifier dan harga NFT
        sleepNFT = new SleepNFT(address(verifierMock), nftPrice);

        // Set kontrak SleepNFT sebagai minter untuk SleepToken dan tetapkan reward token di SleepNFT
        sleepToken.setMinter(address(sleepNFT));
        sleepNFT.setRewardToken(address(sleepToken));

        // Berikan addr1 saldo ether untuk keperluan testing
        vm.deal(addr1, 1 ether);
    }

    function testMultipleNFTsAndUpdateWithStreak() public {
        // addr1 membeli NFT pertama dengan effect = 2, dengan pembayaran nftPrice
        vm.prank(addr1);
        sleepNFT.buySleepNFT{value: nftPrice}("ipfs://nft1", 2);

        // addr1 membeli NFT kedua dengan effect = 3, dengan pembayaran nftPrice
        vm.prank(addr1);
        sleepNFT.buySleepNFT{value: nftPrice}("ipfs://nft2", 3);

        // Verifikasi kepemilikan NFT
        assertEq(sleepNFT.ownerOf(0), addr1);
        assertEq(sleepNFT.ownerOf(1), addr1);

        // Data dummy untuk update sleep data (menggunakan proof valid dari mock)
        bytes memory dummyProof = hex"1234";
        bytes32 dummyRoot = bytes32(0);
        bytes32[] memory dummyPublicInputs = new bytes32[](0);

        // Update pada NFT tokenId 0 dengan startTime = block.timestamp - 3600
        uint256 startTime1 = block.timestamp - 3600; // 10000 - 3600 = 6400
        vm.prank(addr1);
        sleepNFT.updateSleepData(
            0,
            dummyProof,
            dummyRoot,
            dummyPublicInputs,
            50, 60, 1800, 3600, 900,
            startTime1,
            startTime1 + 7200,
            7200,
            75,      // qualityIndex >= goodSleepThreshold (baik)
            "baik"
        );
        SleepDataLib.SleepData[] memory records0 = sleepNFT.getSleepData(0);
        // Expected: baseReward 10e18 * streak (1) * effect (2) = 20e18
        uint256 reward0 = records0[0].rewardAmount;
        assertEq(reward0, 10e18 * 1 * 2);

        // Lakukan update kedua pada NFT tokenId 0 secara berturut-turut (streak naik menjadi 2)
        uint256 startTime2 = startTime1 + 3600; // 6400 + 3600 = 10000
        vm.prank(addr1);
        sleepNFT.updateSleepData(
            0,
            dummyProof,
            dummyRoot,
            dummyPublicInputs,
            55, 65, 1900, 3700, 950,
            startTime2,
            startTime2 + 7200,
            7200,
            80,      // masih baik
            "sangat baik"
        );
        records0 = sleepNFT.getSleepData(0);
        // Expected: streak multiplier naik menjadi 2: reward = 10e18 * 2 * effect (2) = 40e18
        uint256 reward0_second = records0[1].rewardAmount;
        assertEq(reward0_second, 10e18 * 2 * 2);

        // Untuk update pada NFT tokenId 1, gunakan startTime yang lebih besar:
        uint256 startTime3 = startTime2 + 3600; // 10000 + 3600 = 13600
        vm.warp(startTime3); // Update block.timestamp ke 13600 agar _startTime <= block.timestamp
        vm.prank(addr1);
        sleepNFT.updateSleepData(
            1,
            dummyProof,
            dummyRoot,
            dummyPublicInputs,
            50, 60, 1800, 3600, 900,
            startTime3,
            startTime3 + 7200,
            7200,
            75,
            "baik"
        );
        SleepDataLib.SleepData[] memory records1 = sleepNFT.getSleepData(1);
        // Expected: reward = 10e18 * streak (1) * effect (3) = 30e18
        uint256 reward1 = records1[0].rewardAmount;
        assertEq(reward1, 10e18 * 3 * 3);

        // Klaim reward untuk record pertama pada NFT tokenId 0
        vm.prank(addr1);
        sleepNFT.claimReward(0, 0);
        uint256 balanceReward = sleepToken.balanceOf(addr1);
        assertEq(balanceReward, reward0);
    }

    function testUpdateFailsIfInvalidZkProof() public {
        // addr1 membeli NFT dengan pembayaran nftPrice
        vm.prank(addr1);
        sleepNFT.buySleepNFT{value: nftPrice}("ipfs://nft1", 2);

        uint256 tokenId = 0;

        // Set verifier agar mengembalikan false
        verifierMock.setShouldVerify(false);

        bytes memory dummyProof = hex"dead";
        bytes32 dummyRoot = bytes32(0);
        bytes32[] memory dummyPublicInputs = new bytes32[](0);

        vm.prank(addr1);
        vm.expectRevert("Invalid zkTLS proof");
        sleepNFT.updateSleepData(
            tokenId,
            dummyProof,
            dummyRoot,
            dummyPublicInputs,
            50, 60, 1800, 3600, 900,
            block.timestamp - 3600,
            block.timestamp + 3600,
            7200,
            65, // qualityIndex di bawah threshold
            "cukup"
        );
    }
}
