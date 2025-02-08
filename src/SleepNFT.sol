// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

// Interface untuk zkTLS Verifier
interface IZkTLSVerifier {
    function verifyProof(
        bytes calldata proof,
        bytes32 root,
        bytes32[] calldata publicInputs
    ) external view returns (bool);
}

contract SleepNFT is ERC721URIStorage, Ownable {
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
    }

    IZkTLSVerifier public zkTlsVerifier;
    uint256 private _nextTokenId;
    mapping(uint256 => SleepData) public sleepRecords;
    mapping(address => uint256[]) private _userNFTs;
    uint256 public basePrice;
    uint256 public decayRate;

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

    // Hitung harga NFT berdasarkan waktu yang berlalu (mengonversi detik ke jam)
    function calculatePrice(uint256 elapsedTime) public view returns (uint256) {
        uint256 hoursElapsed = elapsedTime / 3600;
        uint256 discount = decayRate * hoursElapsed;
        if (discount >= basePrice) {
            return 0;
        }
        return basePrice - discount;
    }

    // Mint NFT dengan data tidur
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

        // Simpan data tidur
        sleepRecords[tokenId] = SleepData({
            hrv: _hrv,
            rhr: _rhr,
            deepSleep: _deepSleep,
            lightSleep: _lightSleep,
            remSleep: _remSleep,
            startTime: _startTime,
            wakeTime: _wakeTime,
            duration: _duration,
            purchaseTimestamp: block.timestamp
        });

        _userNFTs[msg.sender].push(tokenId);
        emit SleepNFTMinted(msg.sender, tokenId, block.timestamp);
    }

    // Fungsi utilitas
    function getUserNFTs(address user) external view returns (uint256[] memory) {
        return _userNFTs[user];
    }

    function getSleepData(uint256 tokenId) external view returns (SleepData memory) {
        ownerOf(tokenId);
        return sleepRecords[tokenId];
    }

    function setBasePrice(uint256 _newPrice) external onlyOwner {
        basePrice = _newPrice;
    }

    function setDecayRate(uint256 _newDecayRate) external onlyOwner {
        decayRate = _newDecayRate;
    }
}
