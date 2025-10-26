// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract LiskGarden {

    // ============================================
    // BAGIAN 1: ENUM & STRUCT
    // ============================================
    enum GrowthStage { SEED, SPROUT, GROWING, BLOOMING }

    struct Plant {
        uint256 id;
        address owner;
        GrowthStage stage;
        uint256 plantedDate;
        uint256 lastWatered;
        uint8 waterLevel;
        bool exists;
        bool isDead;
    }

    // ============================================
    // BAGIAN 2: STATE VARIABLES
    // ============================================
    mapping(uint256 => Plant) public plants;
    mapping(address => uint256[]) public userPlants;
    uint256 public plantCounter;
    address public owner;

    // ============================================
    // BAGIAN 3: CONSTANTS (Game Parameters)
    // ============================================
    uint256 public constant PLANT_PRICE = 0.001 ether;
    uint256 public constant HARVEST_REWARD = 0.003 ether;
    uint256 public constant STAGE_DURATION = 1 minutes;
    uint256 public constant WATER_DEPLETION_TIME = 30 seconds;
    uint8 public constant WATER_DEPLETION_RATE = 2; // percent per interval

    // ============================================
    // BAGIAN 4: EVENTS
    // ============================================
    event PlantSeeded(address indexed owner, uint256 indexed plantId);
    event PlantWatered(uint256 indexed plantId, uint8 newWaterLevel);
    event PlantHarvested(uint256 indexed plantId, address indexed owner, uint256 reward);
    event StageAdvanced(uint256 indexed plantId, GrowthStage newStage);
    event PlantDied(uint256 indexed plantId);

    // ============================================
    // BAGIAN 5: CONSTRUCTOR
    // ============================================
    constructor() {
        owner = msg.sender;
    }

    // ============================================
    // BAGIAN 6: PLANT SEED (Fungsi Utama #1)
    // ============================================
    function plantSeed() external payable returns (uint256) {
        require(msg.value >= PLANT_PRICE, "Bayar 0.001 ETH untuk menanam");

        plantCounter += 1;
        uint256 newId = plantCounter;

        Plant memory p = Plant({
            id: newId,
            owner: msg.sender,
            stage: GrowthStage.SEED,
            plantedDate: block.timestamp,
            lastWatered: block.timestamp,
            waterLevel: 100,
            exists: true,
            isDead: false
        });

        plants[newId] = p;
        userPlants[msg.sender].push(newId);

        emit PlantSeeded(msg.sender, newId);
        return newId;
    }

    // ============================================
    // BAGIAN 7: WATER SYSTEM (3 Fungsi)
    // ============================================
    function calculateWaterLevel(uint256 plantId) public view returns (uint8) {
        Plant storage plant = plants[plantId];
        if (!plant.exists || plant.isDead) {
            return 0;
        }

        if (block.timestamp <= plant.lastWatered) {
            return plant.waterLevel;
        }

        uint256 timeSinceWatered = block.timestamp - plant.lastWatered;
        uint256 depletionIntervals = timeSinceWatered / WATER_DEPLETION_TIME;
        uint256 waterLost = depletionIntervals * WATER_DEPLETION_RATE; // percent points
        // waterLevel is percentage (0..100)
        if (waterLost >= plant.waterLevel) {
            return 0;
        } else {
            uint256 current = uint256(plant.waterLevel) - waterLost;
            return uint8(current);
        }
    }

    function updateWaterLevel(uint256 plantId) internal {
        Plant storage plant = plants[plantId];
        if (!plant.exists) return;

        uint8 currentWater = calculateWaterLevel(plantId);
        plant.waterLevel = currentWater;

        if (currentWater == 0 && !plant.isDead) {
            plant.isDead = true;
            emit PlantDied(plantId);
        }
    }

    function waterPlant(uint256 plantId) external {
        Plant storage plant = plants[plantId];
        require(plant.exists, "Tanaman tidak ada");
        require(plant.owner == msg.sender, "Bukan pemilik tanaman");
        require(!plant.isDead, "Tanaman sudah mati");

        plant.waterLevel = 100;
        plant.lastWatered = block.timestamp;

        emit PlantWatered(plantId, plant.waterLevel);

        // Update stage as watering might not change stage but consistent to call
        updatePlantStage(plantId);
    }

    // ============================================
    // BAGIAN 8: STAGE & HARVEST (2 Fungsi)
    // ============================================
    function updatePlantStage(uint256 plantId) public {
        Plant storage plant = plants[plantId];
        require(plant.exists, "Tanaman tidak ada");

        // First update water (and possibly death)
        updateWaterLevel(plantId);
        if (plant.isDead) {
            return;
        }

        uint256 timeSincePlanted = block.timestamp - plant.plantedDate;
        GrowthStage oldStage = plant.stage;
        GrowthStage newStage = oldStage;

        if (timeSincePlanted >= 3 * STAGE_DURATION) {
            newStage = GrowthStage.BLOOMING;
        } else if (timeSincePlanted >= 2 * STAGE_DURATION) {
            newStage = GrowthStage.GROWING;
        } else if (timeSincePlanted >= 1 * STAGE_DURATION) {
            newStage = GrowthStage.SPROUT;
        } else {
            newStage = GrowthStage.SEED;
        }

        if (newStage != oldStage) {
            plant.stage = newStage;
            emit StageAdvanced(plantId, newStage);
        }
    }

    function harvestPlant(uint256 plantId) external {
        Plant storage plant = plants[plantId];
        require(plant.exists, "Tanaman tidak ada");
        require(plant.owner == msg.sender, "Bukan pemilik tanaman");
        require(!plant.isDead, "Tanaman sudah mati");

        updatePlantStage(plantId);
        require(plant.stage == GrowthStage.BLOOMING, "Tanaman belum BLOOMING");

        // Mark as removed
        plant.exists = false;

        emit PlantHarvested(plantId, msg.sender, HARVEST_REWARD);

        // Transfer reward
        require(address(this).balance >= HARVEST_REWARD, "Kontrak tidak punya cukup dana");
        (bool success, ) = msg.sender.call{value: HARVEST_REWARD}("");
        require(success, "Transfer gagal");
    }

    // ============================================
    // HELPER FUNCTIONS (Sudah Lengkap)
    // ============================================
    function getPlant(uint256 plantId) external view returns (Plant memory) {
        Plant memory plant = plants[plantId];
        plant.waterLevel = calculateWaterLevel(plantId);
        return plant;
    }

    function getUserPlants(address user) external view returns (uint256[] memory) {
        return userPlants[user];
    }

    function withdraw() external {
        require(msg.sender == owner, "Bukan owner");
        (bool success, ) = owner.call{value: address(this).balance}("");
        require(success, "Transfer gagal");
    }

    receive() external payable {}
}
