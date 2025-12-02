// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

/**
 * @title DigitalTwinSharesV1
 * @notice A bonding curve-based marketplace for digital twin shares
 */
contract DigitalTwinSharesV1 is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
{
    //
    // Events
    //
    event Trade(
        address trader,
        bytes16 digitalTwinId,
        bool isBuy,
        uint256 shareAmount,
        uint256 ethAmount,
        uint256 protocolEthAmount,
        uint256 subjectEthAmount,
        uint256 supply
    );
    event DigitalTwinUrlSet(bytes16 digitalTwinId, string url);
    event DigitalTwinOwnershipClaimed(bytes16 digitalTwinId, address newOwner);
    event ProtocolFeeDestinationSet(address protocolFeeDestination);
    event ProtocolFeePercentSet(uint256 protocolFeePercent);
    event SubjectFeePercentSet(uint256 subjectFeePercent);
    event MinSharesToCreateSet(uint256 minSharesToCreate);

    //
    // State variables
    //

    address public protocolFeeDestination;
    uint256 public protocolFeePercent;
    uint256 public subjectFeePercent;
    uint256 public minSharesToCreate;

    // Role definitions
    bytes32 public constant CLAIM_OWNERSHIP_ROLE = keccak256("CLAIM_OWNERSHIP_ROLE");

    mapping(bytes16 => mapping(address => uint256)) public sharesBalance;
    mapping(bytes16 => string) public digitalTwinUrl;
    mapping(bytes16 => uint256) public sharesSupply;
    mapping(bytes16 => address) public digitalTwinIdToOwner;
    mapping(bytes16 => bool) public digitalTwinExists;

    // Custom modifiers
    modifier onlyDigitalTwinOwner(bytes16 digitalTwinId) {
        require(digitalTwinIdToOwner[digitalTwinId] == msg.sender, "Caller is not the owner of this digital twin");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract
     * @param _initialOwner The initial owner of the contract
     * @param _initialAdmin The initial admin for access control
     * @param _feeDestination The address where protocol fees are sent
     */
    function initialize(address _initialOwner, address _initialAdmin, address _feeDestination) public initializer {
        __UUPSUpgradeable_init();
        __Ownable_init(_initialOwner);
        __AccessControl_init();
        __ReentrancyGuard_init();

        protocolFeeDestination = _feeDestination;
        _grantRole(DEFAULT_ADMIN_ROLE, _initialAdmin);

        // initialize default values
        protocolFeePercent = 0.01 ether; // 1%
        subjectFeePercent = 0.01 ether; // 1%
        minSharesToCreate = 300;
        emit ProtocolFeeDestinationSet(_feeDestination);
        emit ProtocolFeePercentSet(0.01 ether);
        emit SubjectFeePercentSet(0.01 ether);
        emit MinSharesToCreateSet(300);
    }

    /**
     * @notice Authorization function for UUPS upgrades
     * @param newImplementation Address of the new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    //
    // Management functions
    //
    function setFeeDestination(address _feeDestination) public onlyOwner {
        require(_feeDestination != address(0), "Invalid fee destination");
        protocolFeeDestination = _feeDestination;
        emit ProtocolFeeDestinationSet(_feeDestination);
    }

    function setProtocolFeePercent(uint256 _feePercent) public onlyOwner {
        require(_feePercent <= 0.05 ether, "Fee percent must be less than or equal to 5%");
        protocolFeePercent = _feePercent;
        emit ProtocolFeePercentSet(_feePercent);
    }

    function setSubjectFeePercent(uint256 _feePercent) public onlyOwner {
        require(_feePercent <= 0.05 ether, "Fee percent must be less than or equal to 5%");
        subjectFeePercent = _feePercent;
        emit SubjectFeePercentSet(_feePercent);
    }

    function setMinSharesToCreate(uint256 _minSharesToCreate) public onlyOwner {
        require(_minSharesToCreate > 0, "Min shares must be greater than 0");
        minSharesToCreate = _minSharesToCreate;
        emit MinSharesToCreateSet(_minSharesToCreate);
    }

    //
    // Pricing functions
    //
    function getPrice(uint256 supply, uint256 amount) public pure virtual returns (uint256) {
        uint256 sum1 = supply == 0 ? 0 : (supply - 1) * supply * (2 * (supply - 1) + 1) / 6;
        uint256 sum2 = supply == 0 && amount == 1
            ? 0
            : (supply + amount - 1) * (supply + amount) * (2 * (supply + amount - 1) + 1) / 6;
        uint256 summation = sum2 - sum1;

        return summation * 1 ether / 50000000;
    }

    function getBuyPrice(bytes16 digitalTwinId, uint256 amount) public view returns (uint256) {
        return getPrice(sharesSupply[digitalTwinId], amount);
    }

    function getSellPrice(bytes16 digitalTwinId, uint256 amount) public view returns (uint256) {
        return getPrice(sharesSupply[digitalTwinId] - amount, amount);
    }

    function getBuyPriceAfterFee(bytes16 digitalTwinId, uint256 amount) public view returns (uint256) {
        uint256 price = getBuyPrice(digitalTwinId, amount);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 subjectFee = price * subjectFeePercent / 1 ether;
        return price + protocolFee + subjectFee;
    }

    function getSellPriceAfterFee(bytes16 digitalTwinId, uint256 amount) public view returns (uint256) {
        uint256 price = getSellPrice(digitalTwinId, amount);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 subjectFee = price * subjectFeePercent / 1 ether;
        return price - protocolFee - subjectFee;
    }

    //
    // Digital Twin Functions
    //
    function createDigitalTwin(bytes16 digitalTwinId, string memory url) public payable {
        require(!digitalTwinExists[digitalTwinId], "Digital twin already exists");

        digitalTwinIdToOwner[digitalTwinId] = msg.sender;
        digitalTwinExists[digitalTwinId] = true;

        buyShares(digitalTwinId, minSharesToCreate);
        setDigitalTwinUrl(digitalTwinId, url);
    }

    function claimOwnership(bytes16 digitalTwinId, address newOwner) public onlyRole(CLAIM_OWNERSHIP_ROLE) {
        require(newOwner != address(0), "Invalid owner address");
        digitalTwinIdToOwner[digitalTwinId] = newOwner;
        emit DigitalTwinOwnershipClaimed(digitalTwinId, newOwner);
    }

    function setDigitalTwinUrl(bytes16 digitalTwinId, string memory url) public onlyDigitalTwinOwner(digitalTwinId) {
        digitalTwinUrl[digitalTwinId] = url;
        emit DigitalTwinUrlSet(digitalTwinId, url);
    }

    function buyShares(bytes16 digitalTwinId, uint256 amount) public payable virtual nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(digitalTwinExists[digitalTwinId], "Digital twin does not exist");

        uint256 supply = sharesSupply[digitalTwinId];
        uint256 price = getPrice(supply, amount);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 subjectFee = price * subjectFeePercent / 1 ether;
        uint256 totalCost = price + protocolFee + subjectFee;
        require(msg.value >= totalCost, "Insufficient payment");

        sharesBalance[digitalTwinId][msg.sender] += amount;
        sharesSupply[digitalTwinId] = supply + amount;

        emit Trade(msg.sender, digitalTwinId, true, amount, price, protocolFee, subjectFee, supply + amount);

        // transfer fees
        (bool success1,) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success2,) = digitalTwinIdToOwner[digitalTwinId].call{value: subjectFee}("");
        require(success1 && success2, "Unable to send funds");

        // Refund any excess value sent
        uint256 excess = msg.value - totalCost;
        if (excess > 0) {
            (bool refundSuccess,) = msg.sender.call{value: excess}("");
            require(refundSuccess, "Refund failed");
        }
    }

    function sellShares(bytes16 digitalTwinId, uint256 amount, uint256 minPayout) public virtual nonReentrant {
        require(amount > 0, "Amount must be greater than 0");

        uint256 supply = sharesSupply[digitalTwinId];
        require(sharesBalance[digitalTwinId][msg.sender] >= amount, "Insufficient shares");
        require(supply >= amount, "Not enough supply");

        uint256 price = getPrice(supply - amount, amount);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 subjectFee = price * subjectFeePercent / 1 ether;
        uint256 netPayout = price - protocolFee - subjectFee;
        require(netPayout >= minPayout, "Payout is below minimum");

        sharesBalance[digitalTwinId][msg.sender] -= amount;
        sharesSupply[digitalTwinId] = supply - amount;

        emit Trade(msg.sender, digitalTwinId, false, amount, price, protocolFee, subjectFee, supply - amount);

        // transfer funds
        (bool success1,) = msg.sender.call{value: netPayout}("");
        (bool success2,) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success3,) = digitalTwinIdToOwner[digitalTwinId].call{value: subjectFee}("");
        require(success1 && success2 && success3, "Unable to send funds");
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions
     *   to add new variables.
     */
    uint256[50] private __gap;
}