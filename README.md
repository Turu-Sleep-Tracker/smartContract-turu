# Turu - SleepNFT Smart Contract

## Overview
Turu is an NFT-based sleep tracking and reward system that incentivizes users to maintain healthy sleep habits. Users can purchase SleepNFTs, update their sleep data with zkTLS proof, and earn rewards in the form of SleepTokens based on their sleep quality and streaks.

## Features
- **NFT Minting:** Users can purchase SleepNFTs with a set price.
- **Sleep Data Tracking:** Users can update their sleep data, verified using zkTLS proof.
- **Reward System:** Earn SleepTokens based on sleep quality and consecutive good sleep streaks.
- **NFT Effects:** Each NFT has a unique effect (multiplier) that influences the reward amount.
- **Secure Verification:** zkTLS is used to verify sleep data integrity.

## Smart Contract Details

### Contract Name: `SleepNFT`
- **Network Compatibility:** Solidity `^0.8.19`
- **Inherits:**
  - `ERC721URIStorage`
  - `Ownable`
- **Imports:**
  - `@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol`
  - `@openzeppelin/contracts/access/Ownable.sol`
  - `./interfaces/IZkTLSVerifier.sol`
  - `./SleepToken.sol`
  - `./libraries/RewardCalculator.sol`
  - `./libraries/SleepDataLib.sol`

## Functions

### 1. Buy SleepNFT
```solidity
function buySleepNFT(string memory tokenURI, uint256 effect) external payable;
```
- Users can purchase a SleepNFT by paying the `nftPurchasePrice`.
- NFT effects (multipliers) are assigned at purchase.
- Emits `SleepNFTPurchased` event.

### 2. Update Sleep Data
```solidity
function updateSleepData(uint256 tokenId, bytes calldata proof, bytes32 root, bytes32[] calldata publicInputs, uint256 _hrv, uint256 _rhr, uint256 _deepSleep, uint256 _lightSleep, uint256 _remSleep, uint256 _startTime, uint256 _wakeTime, uint256 _duration, uint256 _qualityIndex, string calldata _qualityCategory) external;
```
- Requires zkTLS proof verification.
- Updates user's sleep records.
- Increases streak count if sleep quality meets the threshold.
- Emits `SleepDataUpdated` event.

### 3. Claim Rewards
```solidity
function claimReward(uint256 tokenId, uint256 recordIndex) external;
```
- Allows users to claim SleepToken rewards based on sleep quality.
- Requires the SleepToken contract to be set.
- Rewards are calculated using `RewardCalculator` and multiplied by NFT effects.
- Marks the reward as claimed to prevent double claims.

### 4. Get Sleep Data
```solidity
function getSleepData(uint256 tokenId) external view returns (SleepDataLib.SleepData[] memory);
```
- Returns all stored sleep records for a given NFT.

### 5. Set Reward Token (Owner Only)
```solidity
function setRewardToken(address tokenAddress) external onlyOwner;
```
- Sets the address of the SleepToken contract.

## Events
```solidity
event SleepNFTPurchased(address indexed user, uint256 tokenId, uint256 timestamp, uint256 nftEffect);
event SleepDataUpdated(address indexed user, uint256 tokenId, uint256 recordIndex, uint256 timestamp);
```

## Dependencies
- OpenZeppelin ERC721 & Ownable
- zkTLS Verifier for secure sleep data validation
- SleepToken for issuing rewards
- Custom libraries for reward calculations and sleep data management

## Usage Example
1. Deploy `SleepNFT` contract with zkTLS verifier address and NFT purchase price.
2. Deploy `SleepToken` contract and link it using `setRewardToken`.
3. Users purchase SleepNFTs and update sleep data.
4. Verified sleep data grants rewards, which can be claimed.

## License
This project is licensed under the MIT License.

