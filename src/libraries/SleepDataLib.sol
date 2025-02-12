// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library SleepDataLib {
    struct SleepData {
        uint256 hrv;
        uint256 rhr;
        uint256 deepSleep;
        uint256 lightSleep;
        uint256 remSleep;
        uint256 startTime;
        uint256 wakeTime;
        uint256 duration;
        uint256 purchaseTimestamp; // Waktu saat record dibuat (update data tidur)
        uint256 rewardAmount;      // Reward yang dihitung untuk sesi ini
        bool rewardClaimed;        // Status klaim reward
        uint256 qualityIndex;      // Nilai kualitas tidur (0-100)
        string qualityCategory;    // Kategori tidur (misalnya: "sangat baik", "baik", dll.)
    }
}
