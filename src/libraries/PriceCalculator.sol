// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library PriceCalculator {
    /**
     * @notice Menghitung harga NFT berdasarkan waktu yang berlalu.
     * @param basePrice Harga dasar NFT.
     * @param decayRate Potongan harga per jam.
     * @param elapsedTime Waktu yang berlalu (dalam detik).
     * @return Harga NFT setelah diskon.
     */
    function calculatePrice(
        uint256 basePrice,
        uint256 decayRate,
        uint256 elapsedTime
    ) internal pure returns (uint256) {
        uint256 hoursElapsed = elapsedTime / 3600;
        uint256 discount = decayRate * hoursElapsed;
        if (discount >= basePrice) {
            return 0;
        }
        return basePrice - discount;
    }
}
