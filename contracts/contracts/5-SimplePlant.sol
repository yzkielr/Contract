// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Plant {
    // State Variables
    string public plantName;
    uint256 public waterLevel;
    bool public isAlive;
    address public owner;
    uint256 public plantedTime;

    // Constructor
    constructor() {
        plantName = "Rose";
        waterLevel = 100;
        isAlive = true;
        owner = msg.sender;
        plantedTime = block.timestamp;
    }

    // Fungsi untuk menyiram tanaman
    function water() public {
        waterLevel = 100;
    }

    // Fungsi untuk menghitung umur tanaman
    function getAge() public view returns (uint256) {
        return block.timestamp - plantedTime;
    }
}
