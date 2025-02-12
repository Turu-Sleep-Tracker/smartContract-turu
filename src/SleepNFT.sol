// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IZkTLSVerifier.sol";
import "./SleepToken.sol";
import "./libraries/RewardCalculator.sol";
import "./libraries/SleepDataLib.sol";

contract SleepNFT is ERC721URIStorage, Ownable {
    using RewardCalculator for uint256;

    uint256 private _nextTokenId;
    // Mapping dari tokenId ke array data tidur (setiap elemen adalah satu sesi)
    mapping(uint256 => SleepDataLib.SleepData[]) public sleepRecords;
    // Mapping untuk menyimpan nilai "efek" (multiplier khusus) dari masing-masing NFT
    mapping(uint256 => uint256) public nftEffects;

    // Harga pembelian NFT (biaya tetap)
    uint256 public nftPurchasePrice;
    // Threshold untuk kualitas tidur (misalnya, qualityIndex minimal agar dianggap berkualitas)
    uint256 public goodSleepThreshold = 70;

    IZkTLSVerifier public zkTlsVerifier;
    SleepToken public rewardToken;
   

    // Melacak waktu tidur terakhir dan jumlah sesi tidur berkualitas (streak) per user
    mapping(address => uint256) public lastSleepTimestamp;
    mapping(address => uint256) public consecutiveGoodSleepCount;

    event SleepNFTPurchased(address indexed user, uint256 tokenId, uint256 timestamp, uint256 nftEffect);
    event SleepDataUpdated(address indexed user, uint256 tokenId, uint256 recordIndex, uint256 timestamp);

    constructor(address _zkTlsVerifier, uint256 _nftPurchasePrice)
        ERC721("SleepNFT", "SLEEP")
        Ownable(msg.sender) // Panggil konstruktor Ownable dengan msg.sender
    {
        zkTlsVerifier = IZkTLSVerifier(_zkTlsVerifier);
        nftPurchasePrice = _nftPurchasePrice;
    }

    /// @notice Setter untuk mengatur alamat token reward.
    function setRewardToken(address tokenAddress) external onlyOwner {
        rewardToken = SleepToken(tokenAddress);
    }

    /**
     * @notice Fungsi untuk membeli NFT.
     * @param tokenURI Metadata URI untuk NFT.
     * @param effect Nilai efek (multiplier khusus) yang akan mempengaruhi reward.
     */
    function buySleepNFT(string memory tokenURI, uint256 effect) external payable {
        require(msg.value >= nftPurchasePrice, "Insufficient payment for NFT purchase");

        uint256 tokenId = _nextTokenId++;
        _mint(msg.sender, tokenId);
        _setTokenURI(tokenId, tokenURI);

        // Simpan nilai efek untuk NFT ini
        nftEffects[tokenId] = effect;

        emit SleepNFTPurchased(msg.sender, tokenId, block.timestamp, effect);
    }

    /**
     * @notice Fungsi untuk meng-update data tidur pada NFT tertentu.
     * @param tokenId NFT yang akan di-update (harus dimiliki oleh pemanggil).
     * @param proof Bukti zkTLS.
     * @param root Root untuk verifikasi.
     * @param publicInputs Input publik untuk verifikasi.
     * @param _hrv Nilai HRV.
     * @param _rhr Nilai RHR.
     * @param _deepSleep Durasi deep sleep (detik).
     * @param _lightSleep Durasi light sleep (detik).
     * @param _remSleep Durasi REM sleep (detik).
     * @param _startTime Waktu mulai tidur (harus <= block.timestamp).
     * @param _wakeTime Waktu bangun.
     * @param _duration Durasi tidur.
     * @param _qualityIndex Nilai kualitas tidur (0-100).
     * @param _qualityCategory Kategori tidur (misalnya "sangat baik", "baik", dll).
     */
    function updateSleepData(
    uint256 tokenId,
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
    uint256 _qualityIndex,
    string calldata _qualityCategory
) external {
    require(ownerOf(tokenId) == msg.sender, "Not NFT owner");
    require(_startTime <= block.timestamp, "Start time must be in the past");
    if (lastSleepTimestamp[msg.sender] != 0) {
        require(_startTime >= lastSleepTimestamp[msg.sender], "New start time must be >= last sleep timestamp");
    }
    require(zkTlsVerifier.verifyProof(proof, root, publicInputs), "Invalid zkTLS proof");

    // Update streak (consecutiveGoodSleepCount):
    bool isGoodQuality = (_qualityIndex >= goodSleepThreshold);
    if (isGoodQuality) {
        if (lastSleepTimestamp[msg.sender] != 0 && (_startTime - lastSleepTimestamp[msg.sender]) <= 86400) {
            consecutiveGoodSleepCount[msg.sender] += 1;
        } else {
            consecutiveGoodSleepCount[msg.sender] = 1;
        }
    } else {
        consecutiveGoodSleepCount[msg.sender] = 0;
    }
    lastSleepTimestamp[msg.sender] = _startTime;

    uint256 baseReward = 10 * 1e18;
    uint256 multiplier = consecutiveGoodSleepCount[msg.sender];
    uint256 rewardAmount = RewardCalculator.calculateReward(baseReward, multiplier);
    uint256 effect = nftEffects[tokenId];
    rewardAmount = rewardAmount * effect;

    SleepDataLib.SleepData memory newRecord = SleepDataLib.SleepData({
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
        rewardClaimed: false,
        qualityIndex: _qualityIndex,
        qualityCategory: _qualityCategory
    });

    sleepRecords[tokenId].push(newRecord);
    uint256 recordIndex = sleepRecords[tokenId].length - 1;
    emit SleepDataUpdated(msg.sender, tokenId, recordIndex, block.timestamp);
}


    /**
     * @notice Fungsi untuk mengklaim reward dari record data tidur tertentu.
     * @param tokenId NFT yang dimiliki.
     * @param recordIndex Indeks record data tidur dalam array.
     */
    function claimReward(uint256 tokenId, uint256 recordIndex) external {
        require(ownerOf(tokenId) == msg.sender, "Not NFT owner");
        require(recordIndex < sleepRecords[tokenId].length, "Invalid record index");
        SleepDataLib.SleepData storage record = sleepRecords[tokenId][recordIndex];
        require(!record.rewardClaimed, "Reward already claimed");
        require(address(rewardToken) != address(0), "Reward token not set");
        record.rewardClaimed = true;
        rewardToken.mint(msg.sender, record.rewardAmount);
    }

    /// @notice Fungsi untuk mengambil seluruh data tidur yang tersimpan untuk NFT tertentu.
    function getSleepData(uint256 tokenId) external view returns (SleepDataLib.SleepData[] memory) {
        return sleepRecords[tokenId];
    }
}
