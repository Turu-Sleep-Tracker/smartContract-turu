// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/SleepNFT.sol";
import "../src/SleepToken.sol";
import "../src/mocks/ZkTlsVerifierMock.sol";
import "../src/libraries/SleepDataLib.sol";

contract AllContractsTest is Test {
    SleepNFT public sleepNFT;
    SleepToken public sleepToken;
    ZkTlsVerifierMock public verifierMock;
    address public addr1 = address(0x1);
    // Harga NFT sesuai dengan deployment, misalnya 0.01 ether
    uint256 nftPrice = 0.01 ether;

    function setUp() public {
        // Warp block.timestamp ke nilai nonzero agar perhitungan waktu tidak underflow.
        vm.warp(10000);

        // Deploy mock verifier
        verifierMock = new ZkTlsVerifierMock();

        // Deploy SleepToken
        sleepToken = new SleepToken();

        // Deploy SleepNFT dengan alamat verifier dan harga NFT
        sleepNFT = new SleepNFT(address(verifierMock), nftPrice);

        // Set SleepNFT sebagai minter untuk SleepToken, dan tetapkan reward token di SleepNFT
        sleepToken.setMinter(address(sleepNFT));
        sleepNFT.setRewardToken(address(sleepToken));

        // Berikan addr1 saldo ether untuk keperluan testing
        vm.deal(addr1, 1 ether);
    }

    /// @notice Test untuk memverifikasi fungsi dasar SleepToken.
    function testSleepTokenMinting() public {
        // Hanya minter (SleepNFT) yang boleh mint.
        // Simulasikan panggilan mint dari SleepNFT.
        vm.prank(address(sleepNFT));
        sleepToken.mint(addr1, 100 * 1e18);
        uint256 balance = sleepToken.balanceOf(addr1);
        assertEq(balance, 100 * 1e18, "SleepToken minting failed");
    }

    /// @notice Test untuk memverifikasi fungsi pada ZkTlsVerifierMock.
    function testZkTlsVerifierMock() public {
        // Secara default, verifierMock.shouldVerify bernilai true.
        bool result = verifierMock.verifyProof("0x1234", bytes32(0), new bytes32[](0));
        assertTrue(result, "Verifier harus mengembalikan true secara default");

        // Ubah nilai sehingga proof dianggap tidak valid.
        verifierMock.setShouldVerify(false);
        result = verifierMock.verifyProof("0x1234", bytes32(0), new bytes32[](0));
        assertFalse(result, "Verifier harus mengembalikan false setelah setShouldVerify(false)");
    }

    /// @notice Test untuk memverifikasi flow dasar SleepNFT: pembelian, update data tidur, dan klaim reward.
    function testSleepNFTBasicFlow() public {
        // addr1 membeli NFT dengan efek = 2
        vm.prank(addr1);
        sleepNFT.buySleepNFT{value: nftPrice}("ipfs://nft1", 2);
        uint256 tokenId = 0; // NFT pertama

        // Periksa kepemilikan NFT
        assertEq(sleepNFT.ownerOf(tokenId), addr1, "Owner NFT tidak sesuai");

        // Update data tidur pada NFT tokenId 0
        bytes memory dummyProof = hex"1234";
        bytes32 dummyRoot = bytes32(0);
        bytes32[] memory dummyPublicInputs = new bytes32[](0);
        // Gunakan startTime yang valid: misalnya, block.timestamp - 3600
        uint256 startTime = block.timestamp - 3600;
        vm.prank(addr1);
        sleepNFT.updateSleepData(
            tokenId,
            dummyProof,
            dummyRoot,
            dummyPublicInputs,
            50,    // HRV
            60,    // RHR
            1800,  // deepSleep (detik)
            3600,  // lightSleep (detik)
            900,   // remSleep (detik)
            startTime,
            startTime + 7200,
            7200,
            75,    // qualityIndex (>= goodSleepThreshold)
            "baik"
        );
        SleepDataLib.SleepData[] memory records = sleepNFT.getSleepData(tokenId);
        assertEq(records.length, 1, "Data tidur tidak tersimpan");
        // Expected reward: baseReward 10e18 * streak (1) * effect (2) = 20e18
        uint256 expectedReward = 10e18 * 1 * 2;
        assertEq(records[0].rewardAmount, expectedReward, "Reward per sesi tidak sesuai");

        // Klaim reward dari sesi tersebut
        vm.prank(addr1);
        sleepNFT.claimReward(tokenId, 0);
        uint256 rewardBalance = sleepToken.balanceOf(addr1);
        assertEq(rewardBalance, expectedReward, "Reward token tidak sesuai setelah klaim");
    }

    /// @notice Test untuk memastikan update data tidur gagal jika zkTLS proof tidak valid.
    function testUpdateFailsIfInvalidZkProof() public {
        // addr1 membeli NFT dengan efek = 2
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
