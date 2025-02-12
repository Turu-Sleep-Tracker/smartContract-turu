// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library RewardCalculator {
    /**
     * @notice Menghitung jumlah reward berdasarkan reward dasar dan multiplier.
     * @param baseReward Reward dasar (misalnya 10 token dengan 18 desimal).
     * @param multiplier Pengali (streak multiplier) yang menunjukkan berapa kali tidur berkualitas berturut-turut.
     * @return Jumlah reward yang dihitung.
     */
    function calculateReward(uint256 baseReward, uint256 multiplier) internal pure returns (uint256) {
        return baseReward * multiplier;
    }
}
