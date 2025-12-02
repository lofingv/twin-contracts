// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import {DigitalTwinSharesV1} from "../../src/DigitalTwinSharesV1.sol";

/**
 * @title DigitalTwinSharesV2Mock
 * @notice Mock V2 contract for testing upgrades
 * @dev Adds new functionality while maintaining storage layout
 */
/// @custom:oz-upgrades-from DigitalTwinSharesV1
contract DigitalTwinSharesV2Mock is DigitalTwinSharesV1 {
    // New state variables use the storage gap from V1
    uint256 public referralFeePercent;
    mapping(address => address) public referrers;
    uint256 public totalReferralFeesCollected;

    // New events
    event ReferralSet(address indexed user, address indexed referrer);
    event ReferralFeePaid(address indexed referrer, uint256 amount);

    // Version identifier
    uint256 public constant VERSION = 2;

    /**
     * @notice Reinitializer for V2
     * @param _referralFeePercent Initial referral fee percentage
     */
    function initializeV2(uint256 _referralFeePercent) public reinitializer(2) {
        referralFeePercent = _referralFeePercent;
    }

    /**
     * @notice Set referral fee percentage
     * @param _feePercent New referral fee percentage
     */
    function setReferralFeePercent(uint256 _feePercent) public onlyOwner {
        require(_feePercent <= 0.05 ether, "Referral fee too high"); // Max 5%
        referralFeePercent = _feePercent;
    }

    /**
     * @notice Set referrer for a user
     * @param referrer Address of the referrer
     */
    function setReferrer(address referrer) external {
        require(referrer != msg.sender, "Cannot refer yourself");
        require(referrer != address(0), "Invalid referrer");
        require(referrers[msg.sender] == address(0), "Referrer already set");

        referrers[msg.sender] = referrer;
        emit ReferralSet(msg.sender, referrer);
    }

    /**
     * @notice Override buyShares to include referral logic
     */
    function buySharesV2(bytes16 digitalTwinId, uint256 amount) public payable nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        uint256 supply = sharesSupply[digitalTwinId];

        // New digital twin logic (same as V1)
        if (supply == 0) {
            require(amount >= minSharesToCreate, "Amount must be >= minSharesToCreate");
            if (digitalTwinIdToOwner[digitalTwinId] != address(0)) {
                require(msg.sender == digitalTwinIdToOwner[digitalTwinId], "Only the owner can buy the first share");
            }

            digitalTwinIdToOwner[digitalTwinId] = msg.sender;
            digitalTwinExists[digitalTwinId] = true;
        }

        uint256 price = getPrice(supply, amount);
        uint256 protocolFee = price * protocolFeePercent / 1 ether;
        uint256 subjectFee = price * subjectFeePercent / 1 ether;
        uint256 referralFee = 0;

        // Calculate referral fee if user has a referrer
        if (referrers[msg.sender] != address(0)) {
            referralFee = price * referralFeePercent / 1 ether;
        }

        require(msg.value >= price + protocolFee + subjectFee + referralFee, "Insufficient payment");

        sharesBalance[digitalTwinId][msg.sender] += amount;
        sharesSupply[digitalTwinId] = supply + amount;

        emit Trade(msg.sender, digitalTwinId, true, amount, price, protocolFee, subjectFee, supply + amount);

        // Transfer fees
        (bool success1,) = protocolFeeDestination.call{value: protocolFee}("");
        (bool success2,) = digitalTwinIdToOwner[digitalTwinId].call{value: subjectFee}("");
        require(success1 && success2, "Unable to send funds");

        // Pay referral fee if applicable
        if (referralFee > 0) {
            (bool success3,) = referrers[msg.sender].call{value: referralFee}("");
            if (success3) {
                totalReferralFeesCollected += referralFee;
                emit ReferralFeePaid(referrers[msg.sender], referralFee);
            }
        }

        // Return excess payment
        if (msg.value > price + protocolFee + subjectFee + referralFee) {
            (bool success4,) = msg.sender.call{value: msg.value - price - protocolFee - subjectFee - referralFee}("");
            require(success4, "Unable to return excess payment");
        }
    }

    /**
     * @notice Get the version of the contract
     */
    function getVersion() external pure returns (uint256) {
        return VERSION;
    }
}
