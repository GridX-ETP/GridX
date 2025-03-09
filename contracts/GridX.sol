// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @title GridxToken
 * @dev ERC20 token for representing tokenized energy (TEU - Tokenized Energy Unit)
 */
contract GridxToken is ERC20, ERC20Burnable, Ownable {
    constructor() ERC20("GridxToken", "TEU") Ownable (msg.sender) {
        _mint(msg.sender, 1000000 * 10 ** decimals()); // Initial supply
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}

/**
 * @title GridxMarket
 * @dev Marketplace for trading excess renewable energy
 */
contract GridxMarket is ReentrancyGuard {

    GridxToken public token;
    address public centralNode;
    
    struct EnergyListing {
        address seller;
        uint256 energyAmount;
        uint256 pricePerUnit;
        bool available;
    }

    mapping(uint256 => EnergyListing) public listings;
    uint256 public listingCounter;

    event EnergyListed(uint256 listingId, address indexed seller, uint256 amount, uint256 price);
    event EnergyPurchased(uint256 listingId, address indexed buyer, uint256 amount);

    constructor(address _tokenAddress, address _centralNode) {
        token = GridxToken(_tokenAddress);
        centralNode = _centralNode;
    }

    function listEnergy(uint256 energyAmount, uint256 pricePerUnit) external nonReentrant {
        require(energyAmount > 0, "Amount must be greater than 0");
        require(pricePerUnit > 0, "Price must be greater than 0");

        listings[listingCounter] = EnergyListing(msg.sender, energyAmount, pricePerUnit, true);
        emit EnergyListed(listingCounter, msg.sender, energyAmount, pricePerUnit);
        listingCounter++;
    }

    function buyEnergy(uint256 listingId) external nonReentrant {
        EnergyListing storage listing = listings[listingId];
        require(listing.available, "Energy not available");
        uint256 totalCost = listing.energyAmount * listing.pricePerUnit;
        listing.available = false;

        token.transferFrom(msg.sender, listing.seller, totalCost);
        emit EnergyPurchased(listingId, msg.sender, listing.energyAmount);
    }
}

contract GridxCentralNode is Ownable {
    IERC20 public teuToken;
    uint256 public energyAvailable; // in kWh
    uint256 public basePricePerKWh = 1 * 10**18; // Example: 1 TEU per kWh

    event EnergyAdded(uint256 amount);
    event EnergyPurchased(address indexed buyer, uint256 amount, uint256 price);

    constructor(address _teuToken) Ownable (msg.sender) {
        teuToken = IERC20(_teuToken);
    }

    // Update available energy (only by admin or system oracle)
    function addEnergy(uint256 amount) external onlyOwner {
        energyAvailable += amount;
        emit EnergyAdded(amount);
    }

    // Buy energy from the central node
    function purchaseEnergy(uint256 amount) external {
        require(amount > 0, "Invalid energy amount");
        require(energyAvailable >= amount, "Not enough energy available");

        uint256 price = calculatePrice(amount);
        require(teuToken.transferFrom(msg.sender, owner(), price), "Payment failed");

        energyAvailable -= amount;
        emit EnergyPurchased(msg.sender, amount, price);
    }

    // Dynamic price calculation (can be improved with demand-supply logic)
    function calculatePrice(uint256 amount) public view returns (uint256) {
        return amount * basePricePerKWh;
    }

    // Owner can update price per kWh
    function setBasePrice(uint256 newPrice) external onlyOwner {
        basePricePerKWh = newPrice;
    }
}

/**
 * @title GridxProof
 * @dev Proof of Generation (PoG) and Proof of Consumption (PoC) validation
 * @notice Might need external form of verification but for now, we go simple
 */
contract GridxProof {
    GridxToken public token;
    mapping(address => uint256) public generatedPower;
    mapping(address => uint256) public consumedPower;
    
    event ProofSubmitted(address indexed user, uint256 amount, string proofType);
    
    constructor(address _tokenAddress) {
        token = GridxToken(_tokenAddress);
    }

    function submitProofOfGeneration(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        generatedPower[msg.sender] += amount;
        emit ProofSubmitted(msg.sender, amount, "Generation");
    }
    
    function submitProofOfConsumption(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        consumedPower[msg.sender] += amount;
        emit ProofSubmitted(msg.sender, amount, "Consumption");
    }
}

