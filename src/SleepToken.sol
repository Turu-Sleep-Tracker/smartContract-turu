// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SleepToken is ERC20, Ownable {
    address public minter;

    constructor() ERC20("SleepToken", "SLP") Ownable(msg.sender) {
        // Konstruktor Ownable sekarang menerima msg.sender sebagai initialOwner.
    }

    modifier onlyMinter() {
        require(msg.sender == minter, "Not minter");
        _;
    }

    function setMinter(address _minter) external onlyOwner {
        minter = _minter;
    }

    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }
}
