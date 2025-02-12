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
    ZkTlsVerifierMock public verifier;
    address public user = address(0x1);
    uint256 public nftPrice = 0.01 ether;

    function setUp() public {
        // Set block.timestamp ke nilai nonzero
        vm.warp(10000);

        verifier = new ZkTlsVerifierMock();
        sleepToken = new SleepToken();
        sleepNFT = new SleepNFT(address(verifier), nftPrice);

        // Set SleepNFT sebagai minter untuk SleepToken
        sleepToken.setMinter(address(sleepNFT));
        sleepNFT.setRewardToken(address(sleepToken));

        // Berikan user saldo ether untuk keperluan test
        vm.deal(user, 1 ether);
    }

    function testBuyAndUpdateWithStreak() public {
        // User membeli dua NFT dengan efek berbeda
        vm.prank(user);
        sleepNFT.buySleepNFT{value: nftPrice}("ipfs://nft1", 2);
        vm.prank(user);
        sleepNFT.buySleepNFT{value: nftPrice}("ipfs://nft2", 3);

        // Verifikasi kepemilikan NFT
        assertEq(sleepNFT.ownerOf(0), user, "NFT tokenId 0 harus dimiliki user");
        assertEq(sleepNFT.ownerOf(1), user, "NFT tokenId 1 harus dimiliki user");

        // Update data tidur pada NFT tokenId 0
        bytes memory dummyProof = hex"1234";
        bytes32 dummyRoot = bytes32(0);
        bytes32[] memory dummyPublicInputs = new bytes32[](0);

        // Update pertama untuk NFT tokenId 0
        uint256 startTime1 = block.timestamp - 3600; // misal: 10000 - 3600 = 6400
        vm.prank(user);
        sleepNFT.updateSleepData(
            0,
            dummyProof,
            dummyRoot,
            dummyPublicInputs,
            50, 60, 1800, 3600, 900,
            startTime1,
            startTime1 + 7200,
            7200,
            75,      // qualityIndex >= threshold (baik)
            "baik"
        );
        SleepDataLib.SleepData[] memory records0 = sleepNFT.getSleepData(0);
        uint256 expectedReward0 = 10e18 * 1 * 2; // baseReward * streak (1) * effect (2)
        assertEq(records0[0].rewardAmount, expectedReward0, "Reward sesi pertama tidak sesuai");

        // Update kedua untuk NFT tokenId 0 (streak naik menjadi 2)
        uint256 startTime2 = startTime1 + 3600; // 6400 + 3600 = 10000
        vm.prank(user);
        sleepNFT.updateSleepData(
            0,
            dummyProof,
            dummyRoot,
            dummyPublicInputs,
            55, 65, 1900, 3700, 950,
            startTime2,
            startTime2 + 7200,
            7200,
            80,      // qualityIndex masih baik
            "sangat baik"
        );
        records0 = sleepNFT.getSleepData(0);
        uint256 expectedReward0_second = 10e18 * 2 * 2; // baseReward * streak (2) * effect (2)
        assertEq(records0[1].rewardAmount, expectedReward0_second, "Reward sesi kedua tidak sesuai");

        // Update untuk NFT tokenId 1
        uint256 startTime3 = startTime2 + 3600; // 10000 + 3600 = 13600
        vm.warp(startTime3); // Warp agar block.timestamp >= startTime3
        vm.prank(user);
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
        // Karena streak global sudah naik menjadi 3 (update sebelumnya: streak 1 dan 2), reward = 10e18 * 3 * effect (3) = 90e18
        uint256 expectedReward1 = 10e18 * 3 * 3;
        assertEq(records1[0].rewardAmount, expectedReward1, "Reward pada NFT tokenId 1 tidak sesuai");

        // Klaim reward dari sesi pertama pada NFT tokenId 0
        vm.prank(user);
        sleepNFT.claimReward(0, 0);
        uint256 userRewardBalance = sleepToken.balanceOf(user);
        assertEq(userRewardBalance, expectedReward0, "Reward token setelah klaim tidak sesuai");
    }
}
