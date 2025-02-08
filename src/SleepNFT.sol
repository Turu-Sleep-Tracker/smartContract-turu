// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/// Interface untuk zkTLS Verifier
interface IZkTLSVerifier {
    function verifyProof(
        bytes calldata proof,
        bytes32 root,
        bytes32[] calldata publicInputs
    ) external view returns (bool);
}

// Import SleepToken (reward token)
import "./SleepToken.sol";

contract SleepNFT is ERC721URIStorage, Ownable {
    // Struktur data tidur diperluas dengan reward info
    struct SleepData {
        uint256 hrv;
        uint256 rhr;
        uint256 deepSleep;
        uint256 lightSleep;
        uint256 remSleep;
        uint256 startTime;
        uint256 wakeTime;
        uint256 duration;
        uint256 purchaseTimestamp;
        uint256 rewardAmount; // jumlah token reward yang dihitung
        bool rewardClaimed;   // status klaim reward
    }

    IZkTLSVerifier public zkTlsVerifier;
    uint256 private _nextTokenId;
    mapping(uint256 => SleepData) public sleepRecords;
    mapping(address => uint256[]) private _userNFTs;
    uint256 public basePrice;
    uint256 public decayRate;

    // Variabel untuk reward
    SleepToken public rewardToken;
    // Untuk melacak sesi tidur terakhir per user dan jumlah tidur berkualitas berturut-turut
    mapping(address => uint256) public lastSleepTimestamp;
    mapping(address => uint256) public consecutiveGoodSleepCount;

    event SleepNFTMinted(address indexed user, uint256 tokenId, uint256 timestamp);

    constructor(
        address _zkTlsVerifier,
        uint256 _basePrice,
        uint256 _decayRate
    )
        ERC721("SleepNFT", "SLEEP")
        Ownable(msg.sender)
    {
        zkTlsVerifier = IZkTLSVerifier(_zkTlsVerifier);
        basePrice = _basePrice;
        decayRate = _decayRate;
    }

    // Setter untuk mengatur alamat reward token (SleepToken)
    function setRewardToken(address tokenAddress) external onlyOwner {
        rewardToken = SleepToken(tokenAddress);
    }

    /// Hitung harga NFT berdasarkan waktu yang berlalu (mengonversi detik ke jam)
    function calculatePrice(uint256 elapsedTime) public view returns (uint256) {
        uint256 hoursElapsed = elapsedTime / 3600;
        uint256 discount = decayRate * hoursElapsed;
        if (discount >= basePrice) {
            return 0;
        }
        return basePrice - discount;
    }

    /// Mint NFT dengan data tidur dan hitung reward berdasarkan kualitas tidur
    function mintSleepNFT(
        bytes calldata proof,
        bytes32 root,
        bytes32[] calldata publicInputs,
        uint256 _hrv,
        uint256 _rhr,
        uint256 _deepSleep,
        uint256 _lightSleep,
        uint256 _remSleep,
        uint256 _startTime,
        uint256 _wakeTime,
        uint256 _duration,
        string memory _tokenURI
    ) external payable {
        // Validasi zkTLS proof
        require(
            zkTlsVerifier.verifyProof(proof, root, publicInputs),
            "Invalid zkTLS proof"
        );

        // Pastikan _startTime tidak di masa depan
        require(_startTime <= block.timestamp, "Start time must be in the past");

        // Hitung harga NFT (elapsedTime dalam detik)
        uint256 elapsedTime = block.timestamp - _startTime;
        uint256 nftPrice = calculatePrice(elapsedTime);
        require(msg.value >= nftPrice, "Insufficient payment");

        // Mint NFT
        uint256 tokenId = _nextTokenId++;
        _mint(msg.sender, tokenId);
        _setTokenURI(tokenId, _tokenURI);

        // --- Hitung reward ---
        // Misalnya: baseReward adalah 10 token (dengan 18 desimal)
        uint256 baseReward = 10 * 1e18;

        // Tentukan "kualitas tidur" secara sederhana:
        // Jika deepSleep minimal 30% dari total duration, maka dianggap tidur berkualitas.
        // Pastikan _duration > 0 untuk menghindari pembagian dengan nol.
        bool isGoodQuality = (_duration > 0) && ((_deepSleep * 100) / _duration >= 30);

        // Jika tidur berkualitas dan jika sesi tidur ini terjadi dalam 24 jam setelah sesi sebelumnya,
        // maka tingkatkan penghitung tidur berturut-turut. Jika tidak, set ke 1 (atau 0 jika tidak bagus).
        if (isGoodQuality) {
            if (lastSleepTimestamp[msg.sender] != 0 && (_startTime - lastSleepTimestamp[msg.sender]) <= 86400) {
                consecutiveGoodSleepCount[msg.sender] += 1;
            } else {
                consecutiveGoodSleepCount[msg.sender] = 1;
            }
        } else {
            consecutiveGoodSleepCount[msg.sender] = 0;
        }
        // Update waktu tidur terakhir
        lastSleepTimestamp[msg.sender] = _startTime;

        // Multiplier berdasarkan jumlah sesi tidur berkualitas berturut-turut
        uint256 multiplier = consecutiveGoodSleepCount[msg.sender];
        uint256 rewardAmount = baseReward * multiplier;
        // ---------------------------------

        // Simpan data tidur bersama reward
        sleepRecords[tokenId] = SleepData({
            hrv: _hrv,
            rhr: _rhr,
            deepSleep: _deepSleep,
            lightSleep: _lightSleep,
            remSleep: _remSleep,
            startTime: _startTime,
            wakeTime: _wakeTime,
            duration: _duration,
            purchaseTimestamp: block.timestamp,
            rewardAmount: rewardAmount,
            rewardClaimed: false
        });

        _userNFTs[msg.sender].push(tokenId);
        emit SleepNFTMinted(msg.sender, tokenId, block.timestamp);
    }

    // Fungsi utilitas untuk mengambil daftar NFT milik user
    function getUserNFTs(address user) external view returns (uint256[] memory) {
        return _userNFTs[user];
    }

    // Fungsi utilitas untuk mendapatkan data tidur dari NFT
    function getSleepData(uint256 tokenId) external view returns (SleepData memory) {
        ownerOf(tokenId);
        return sleepRecords[tokenId];
    }

    // Fungsi untuk mengklaim reward token untuk NFT tertentu
    function claimReward(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Not NFT owner");
        SleepData storage data = sleepRecords[tokenId];
        require(!data.rewardClaimed, "Reward already claimed");
        require(address(rewardToken) != address(0), "Reward token not set");
        data.rewardClaimed = true;
        // Mint token reward ke wallet pengguna
        rewardToken.mint(msg.sender, data.rewardAmount);
    }

    // Fungsi admin untuk mengubah harga dasar dan decay rate
    function setBasePrice(uint256 _newPrice) external onlyOwner {
        basePrice = _newPrice;
    }

    function setDecayRate(uint256 _newDecayRate) external onlyOwner {
        decayRate = _newDecayRate;
    }
}
