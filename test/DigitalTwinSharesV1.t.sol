// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import {Test, console} from "forge-std/Test.sol";
import {DigitalTwinSharesV1} from "../src/DigitalTwinSharesV1.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/src/Upgrades.sol";

/**
 * @title ComprehensiveDigitalTwinTests
 * @notice Exhaustive test suite covering all attack vectors and edge cases
 */
contract ComprehensiveDigitalTwinTests is Test {
    event ProtocolFeeDestinationSet(address protocolFeeDestination);
    event ProtocolFeePercentSet(uint256 protocolFeePercent);
    event SubjectFeePercentSet(uint256 subjectFeePercent);
    event MinSharesToCreateSet(uint256 minSharesToCreate);

    DigitalTwinSharesV1 public proxy;
    address public proxyAddress;

    address public owner;
    address public admin;
    address public feeDestination;
    address public user1;
    address public user2;
    address public user3;
    address public attacker;
    address public maliciousContract;

    bytes16 public constant TWIN_ID_1 = 0xca75c1a75c1a75c1a75c1a75c1a75c1b;
    bytes16 public constant TWIN_ID_2 = 0xfedcba9876543210fedcba9876543211;
    bytes16 public constant TWIN_ID_3 = 0x1a2b3c4d5e6f7a8b1a2b3c4d5e6f7a8c;

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

    function setUp() public {
        owner = makeAddr("owner");
        admin = makeAddr("admin");
        feeDestination = makeAddr("feeDestination");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        attacker = makeAddr("attacker");

        vm.deal(owner, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
        vm.deal(attacker, 100 ether);

        // Deploy using UUPS proxy pattern
        vm.startPrank(owner);
        proxyAddress = Upgrades.deployUUPSProxy(
            "DigitalTwinSharesV1.sol", abi.encodeCall(DigitalTwinSharesV1.initialize, (owner, admin, feeDestination))
        );
        vm.stopPrank();

        proxy = DigitalTwinSharesV1(proxyAddress);

        // Set reasonable defaults
        vm.startPrank(owner);
        proxy.setProtocolFeePercent(0.01 ether); // 1%
        proxy.setSubjectFeePercent(0.01 ether); // 1%
        proxy.setMinSharesToCreate(2);
        vm.stopPrank();
    }

    // ============================================
    // INITIALIZATION TESTS
    // ============================================

    function testCannotReinitialize() public {
        vm.expectRevert();
        proxy.initialize(attacker, attacker, attacker);
    }

    function testImplementationIsLocked() public {
        address implementationAddress = Upgrades.getImplementationAddress(proxyAddress);
        DigitalTwinSharesV1 implementation = DigitalTwinSharesV1(implementationAddress);

        vm.expectRevert();
        implementation.initialize(attacker, attacker, attacker);
    }

    function testInitializationSetsCorrectValues() public view {
        assertEq(proxy.owner(), owner);
        assertEq(proxy.protocolFeeDestination(), feeDestination);
        assertEq(proxy.protocolFeePercent(), 0.01 ether);
        assertEq(proxy.subjectFeePercent(), 0.01 ether);
        assertEq(proxy.minSharesToCreate(), 2);
        assertTrue(proxy.hasRole(proxy.DEFAULT_ADMIN_ROLE(), admin));
    }

    // ============================================
    // ACCESS CONTROL TESTS
    // ============================================

    function testOnlyOwnerCanSetFeeDestination() public {
        address newDest = makeAddr("newDest");

        vm.prank(attacker);
        vm.expectRevert();
        proxy.setFeeDestination(newDest);

        vm.prank(owner);
        vm.expectEmit();
        emit ProtocolFeeDestinationSet(newDest);
        proxy.setFeeDestination(newDest);
        assertEq(proxy.protocolFeeDestination(), newDest);
    }

    function testCannotSetZeroFeeDestination() public {
        vm.prank(owner);
        vm.expectRevert("Invalid fee destination");
        proxy.setFeeDestination(address(0));
    }

    function testOnlyOwnerCanSetFees() public {
        vm.prank(attacker);
        vm.expectRevert();
        proxy.setProtocolFeePercent(0.05 ether);

        vm.prank(owner);
        vm.expectEmit();
        emit ProtocolFeePercentSet(0.05 ether);
        proxy.setProtocolFeePercent(0.05 ether);
        assertEq(proxy.protocolFeePercent(), 0.05 ether);

        vm.prank(owner);
        vm.expectRevert("Fee percent must be less than or equal to 5%");
        proxy.setProtocolFeePercent(0.06 ether);
    }

    function testOnlyOwnerCanSetMinShares() public {
        vm.prank(attacker);
        vm.expectRevert();
        proxy.setMinSharesToCreate(100);

        vm.prank(owner);
        vm.expectEmit();
        emit MinSharesToCreateSet(100);
        proxy.setMinSharesToCreate(100);
        assertEq(proxy.minSharesToCreate(), 100);
    }

    function testCannotSetMinSharesToZero() public {
        vm.prank(owner);
        vm.expectRevert("Min shares must be greater than 0");
        proxy.setMinSharesToCreate(0);
    }

    function testOnlyOwnerCanUpgrade() public {
        DigitalTwinSharesV1 newImplementation = new DigitalTwinSharesV1();
        address currentImpl = Upgrades.getImplementationAddress(proxyAddress);

        vm.prank(attacker);
        vm.expectRevert(); // Will revert with OwnableUnauthorizedAccount
        proxy.upgradeToAndCall(address(newImplementation), "");

        assertEq(Upgrades.getImplementationAddress(proxyAddress), currentImpl, "Implementation should not change");

        vm.prank(admin);
        vm.expectRevert(); // Will revert with OwnableUnauthorizedAccount
        proxy.upgradeToAndCall(address(newImplementation), "");

        assertEq(Upgrades.getImplementationAddress(proxyAddress), currentImpl, "Implementation should still not change");

        vm.prank(owner);
        proxy.upgradeToAndCall(address(newImplementation), "");

        assertEq(
            Upgrades.getImplementationAddress(proxyAddress),
            address(newImplementation),
            "Implementation should now be updated"
        );
    }

    function testAdminCanGrantClaimOwnershipRole() public {
        vm.startPrank(admin);
        proxy.grantRole(proxy.CLAIM_OWNERSHIP_ROLE(), admin);
        assertTrue(proxy.hasRole(proxy.DEFAULT_ADMIN_ROLE(), admin), "Admin should have DEFAULT_ADMIN_ROLE");
        assertTrue(proxy.hasRole(proxy.CLAIM_OWNERSHIP_ROLE(), admin), "Admin should have CLAIM_OWNERSHIP_ROLE");
        vm.stopPrank();

        vm.startPrank(admin);
        proxy.grantRole(proxy.CLAIM_OWNERSHIP_ROLE(), user1);
        assertTrue(proxy.hasRole(proxy.CLAIM_OWNERSHIP_ROLE(), user1));
        vm.stopPrank();
    }

    function testOnlyClaimOwnershipRoleCanClaimOwnership() public {
        vm.startPrank(attacker);
        vm.expectRevert();
        proxy.claimOwnership(TWIN_ID_1, attacker);
        vm.stopPrank();

        vm.startPrank(admin);
        proxy.grantRole(proxy.CLAIM_OWNERSHIP_ROLE(), user1);
        vm.stopPrank();

        vm.startPrank(user1);
        proxy.claimOwnership(TWIN_ID_1, user2);
        vm.stopPrank();
    }

    function testCannotClaimOwnershipToZeroAddress() public {
        vm.startPrank(admin);
        proxy.grantRole(proxy.CLAIM_OWNERSHIP_ROLE(), user1);
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert("Invalid owner address");
        proxy.claimOwnership(TWIN_ID_1, address(0));
    }

    function testAdminCannotBecomeOwner() public {
        // Admin cannot call owner-only functions
        vm.startPrank(admin);

        vm.expectRevert();
        proxy.setFeeDestination(admin);

        vm.expectRevert();
        proxy.setProtocolFeePercent(0.5 ether);

        DigitalTwinSharesV1 newImpl = new DigitalTwinSharesV1();
        vm.expectRevert();
        proxy.upgradeToAndCall(address(newImpl), "");

        vm.stopPrank();
    }

    // ============================================
    // DIGITAL TWIN CREATION TESTS
    // ============================================

    function testCreateDigitalTwin() public {
        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);

        vm.prank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");

        assertTrue(proxy.digitalTwinExists(TWIN_ID_1));
        assertEq(proxy.digitalTwinIdToOwner(TWIN_ID_1), user1);
        assertEq(proxy.sharesSupply(TWIN_ID_1), 2);
        assertEq(proxy.sharesBalance(TWIN_ID_1, user1), 2);
        assertEq(proxy.digitalTwinUrl(TWIN_ID_1), "https://twin.com");
    }

    function testCannotCreateDuplicateDigitalTwin() public {
        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);

        vm.prank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");

        vm.prank(user2);
        vm.expectRevert("Digital twin already exists");
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin2.com");
    }

    function testCreateDigitalTwinRequiresSufficientPayment() public {
        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);

        vm.prank(user1);
        vm.expectRevert("Insufficient payment");
        proxy.createDigitalTwin{value: cost - 1}(TWIN_ID_1, "https://twin.com");
    }

    function testCreateDigitalTwinRefundsExcess() public {
        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        uint256 basePrice = proxy.getBuyPrice(TWIN_ID_1, 2);
        uint256 excess = 1 ether;

        uint256 contractBalanceBefore = address(proxy).balance;

        vm.prank(user1);
        proxy.createDigitalTwin{value: cost + excess}(TWIN_ID_1, "https://twin.com");

        uint256 contractBalanceAfter = address(proxy).balance;

        assertEq(contractBalanceAfter, contractBalanceBefore + basePrice, "Contract should not keep excess ETH");
    }

    // ============================================
    // BUY SHARES TESTS
    // ============================================

    function testBuyShares() public {
        // Create twin
        uint256 createCost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        vm.prank(user1);
        proxy.createDigitalTwin{value: createCost}(TWIN_ID_1, "https://twin.com");

        // Buy shares
        uint256 buyCost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 3);
        uint256 supplyBefore = proxy.sharesSupply(TWIN_ID_1);

        vm.prank(user2);
        proxy.buyShares{value: buyCost}(TWIN_ID_1, 3);

        assertEq(proxy.sharesBalance(TWIN_ID_1, user2), 3);
        assertEq(proxy.sharesSupply(TWIN_ID_1), supplyBefore + 3);
    }

    function testCannotBuyZeroShares() public {
        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        vm.prank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");

        vm.prank(user2);
        vm.expectRevert("Amount must be greater than 0");
        proxy.buyShares{value: 1 ether}(TWIN_ID_1, 0);
    }

    function testCannotBuyFromNonExistentTwin() public {
        vm.prank(user1);
        vm.expectRevert("Digital twin does not exist");
        proxy.buyShares{value: 1 ether}(TWIN_ID_1, 1);
    }

    function testBuySharesRequiresSufficientPayment() public {
        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        vm.prank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");

        uint256 buyCost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 5);

        vm.prank(user2);
        vm.expectRevert("Insufficient payment");
        proxy.buyShares{value: buyCost - 1}(TWIN_ID_1, 5);
    }

    function testBuySharesRefundsExcess() public {
        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        vm.prank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");

        uint256 buyCost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 3);
        uint256 excess = 5 ether;
        uint256 balanceBefore = user2.balance;

        vm.prank(user2);
        proxy.buyShares{value: buyCost + excess}(TWIN_ID_1, 3);

        assertEq(user2.balance, balanceBefore - buyCost);
    }

    function testBuySharesDistributesFees() public {
        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        vm.prank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");

        uint256 buyCost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 5);
        uint256 basePrice = proxy.getBuyPrice(TWIN_ID_1, 5);
        uint256 protocolFee = basePrice * 0.01 ether / 1 ether;
        uint256 subjectFee = basePrice * 0.01 ether / 1 ether;

        uint256 feeDestBalanceBefore = feeDestination.balance;
        
        // We check claimableFees instead of direct balance
        uint256 claimableBefore = proxy.claimableFees(user1);

        vm.prank(user2);
        proxy.buyShares{value: buyCost}(TWIN_ID_1, 5);

        assertEq(feeDestination.balance, feeDestBalanceBefore + protocolFee);
        assertEq(proxy.claimableFees(user1), claimableBefore + subjectFee);
    }

    function testBuySharesEmitsTradeEvent() public {
        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        vm.prank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");

        uint256 buyCost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 3);
        uint256 basePrice = proxy.getBuyPrice(TWIN_ID_1, 3);
        uint256 protocolFee = basePrice * 0.01 ether / 1 ether;
        uint256 subjectFee = basePrice * 0.01 ether / 1 ether;

        vm.expectEmit(true, true, true, true);
        emit Trade(user2, TWIN_ID_1, true, 3, basePrice, protocolFee, subjectFee, 5);

        vm.prank(user2);
        proxy.buyShares{value: buyCost}(TWIN_ID_1, 3);
    }

    function testBuySharesPriceIncreases() public {
        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        vm.prank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");

        uint256 price1 = proxy.getBuyPrice(TWIN_ID_1, 1);

        vm.prank(user2);
        proxy.buyShares{value: 1 ether}(TWIN_ID_1, 5);

        uint256 price2 = proxy.getBuyPrice(TWIN_ID_1, 1);

        assertGt(price2, price1);
    }

    // ============================================
    // SELL SHARES TESTS
    // ============================================

    function testSellShares() public {
        // Create and buy
        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        vm.prank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");

        vm.prank(user2);
        proxy.buyShares{value: 1 ether}(TWIN_ID_1, 5);

        // Sell
        uint256 balanceBefore = user2.balance;
        uint256 supplyBefore = proxy.sharesSupply(TWIN_ID_1);
        uint256 payout = proxy.getSellPriceAfterFee(TWIN_ID_1, 2);

        vm.prank(user2);
        proxy.sellShares(TWIN_ID_1, 2, 0);

        assertEq(proxy.sharesBalance(TWIN_ID_1, user2), 3);
        assertEq(proxy.sharesSupply(TWIN_ID_1), supplyBefore - 2);
        assertEq(user2.balance, balanceBefore + payout);
    }

    function testCannotSellZeroShares() public {
        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        vm.prank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");

        vm.prank(user1);
        vm.expectRevert("Amount must be greater than 0");
        proxy.sellShares(TWIN_ID_1, 0, 0);
    }

    function testCannotSellMoreThanOwned() public {
        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        vm.prank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");

        vm.prank(user1);
        vm.expectRevert("Insufficient shares");
        proxy.sellShares(TWIN_ID_1, 3, 0);
    }

    function testSellSharesRespectsMinPayout() public {
        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        vm.prank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");

        uint256 payout = proxy.getSellPriceAfterFee(TWIN_ID_1, 1);

        vm.prank(user1);
        vm.expectRevert("Payout is below minimum");
        proxy.sellShares(TWIN_ID_1, 1, payout + 1);
    }

    function testSellSharesDistributesFees() public {
        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        vm.prank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");

        vm.prank(user2);
        proxy.buyShares{value: 1 ether}(TWIN_ID_1, 10);

        uint256 basePrice = proxy.getSellPrice(TWIN_ID_1, 5);
        uint256 protocolFee = basePrice * 0.01 ether / 1 ether;
        uint256 subjectFee = basePrice * 0.01 ether / 1 ether;

        uint256 feeDestBalanceBefore = feeDestination.balance;
        uint256 claimableBefore = proxy.claimableFees(user1);

        vm.prank(user2);
        proxy.sellShares(TWIN_ID_1, 5, 0);

        assertEq(feeDestination.balance, feeDestBalanceBefore + protocolFee);
        assertEq(proxy.claimableFees(user1), claimableBefore + subjectFee);
    }

    function testSellSharesEmitsTradeEvent() public {
        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        vm.prank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");

        uint256 basePrice = proxy.getSellPrice(TWIN_ID_1, 1);
        uint256 protocolFee = basePrice * 0.01 ether / 1 ether;
        uint256 subjectFee = basePrice * 0.01 ether / 1 ether;

        vm.expectEmit(true, true, true, true);
        emit Trade(user1, TWIN_ID_1, false, 1, basePrice, protocolFee, subjectFee, 1);

        vm.prank(user1);
        proxy.sellShares(TWIN_ID_1, 1, 0);
    }

    function testSellAllShares() public {
        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        vm.startPrank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");
        vm.stopPrank();

        vm.startPrank(user2);
        proxy.buyShares{value: 1 ether}(TWIN_ID_1, 5);
        vm.stopPrank();

        vm.startPrank(user1);
        proxy.sellShares(TWIN_ID_1, 2, 0);
        vm.stopPrank();

        vm.startPrank(user2);
        proxy.sellShares(TWIN_ID_1, 5, 0);
        vm.stopPrank();

        assertEq(address(proxy).balance, 0);
        assertTrue(proxy.digitalTwinExists(TWIN_ID_1));
        assertEq(proxy.sharesSupply(TWIN_ID_1), 0);

        // buy 2 shares
        vm.startPrank(user2);
        proxy.buyShares{value: 1 ether}(TWIN_ID_1, 2);
        vm.stopPrank();

        assertEq(proxy.sharesSupply(TWIN_ID_1), 2);
        assertEq(proxy.sharesBalance(TWIN_ID_1, user2), 2);
    }

    // ============================================
    // PRICING TESTS
    // ============================================

    function testGetPriceForZeroSupply() public view {
        uint256 price = proxy.getPrice(0, 1);
        assertEq(price, 0);
    }

    function testGetPriceIncreasesWithSupply() public view {
        uint256 price1 = proxy.getPrice(10, 1);
        uint256 price2 = proxy.getPrice(100, 1);
        uint256 price3 = proxy.getPrice(1000, 1);

        assertGt(price2, price1);
        assertGt(price3, price2);
    }

    function testGetPriceIncreasesWithAmount() public view {
        uint256 price1 = proxy.getPrice(10, 1);
        uint256 price2 = proxy.getPrice(10, 5);
        uint256 price3 = proxy.getPrice(10, 10);

        assertGt(price2, price1);
        assertGt(price3, price2);
    }

    function testBuyPriceMatchesGetPrice() public {
        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        vm.prank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");

        uint256 supply = proxy.sharesSupply(TWIN_ID_1);
        uint256 buyPrice = proxy.getBuyPrice(TWIN_ID_1, 5);
        uint256 getPrice = proxy.getPrice(supply, 5);

        assertEq(buyPrice, getPrice);
    }

    function testSellPriceMatchesGetPrice() public {
        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        vm.prank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");

        uint256 supply = proxy.sharesSupply(TWIN_ID_1);
        uint256 sellPrice = proxy.getSellPrice(TWIN_ID_1, 1);
        uint256 getPrice = proxy.getPrice(supply - 1, 1);

        assertEq(sellPrice, getPrice);
    }

    function testPriceAfterFeeIncludesAllFees() public {
        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        vm.prank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");

        uint256 basePrice = proxy.getBuyPrice(TWIN_ID_1, 5);
        uint256 protocolFee = basePrice * 0.01 ether / 1 ether;
        uint256 subjectFee = basePrice * 0.01 ether / 1 ether;
        uint256 priceAfterFee = proxy.getBuyPriceAfterFee(TWIN_ID_1, 5);

        assertEq(priceAfterFee, basePrice + protocolFee + subjectFee);
    }

    // ============================================
    // DIGITAL TWIN URL TESTS
    // ============================================

    function testOnlyOwnerCanSetUrl() public {
        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        vm.prank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");

        vm.prank(user2);
        vm.expectRevert("Caller is not the owner of this digital twin");
        proxy.setDigitalTwinUrl(TWIN_ID_1, "https://hacked.com");

        vm.prank(user1);
        proxy.setDigitalTwinUrl(TWIN_ID_1, "https://newtwin.com");
        assertEq(proxy.digitalTwinUrl(TWIN_ID_1), "https://newtwin.com");
    }

    // ============================================
    // REENTRANCY TESTS
    // ============================================

    function testReentrancyProtectionOnBuyShares() public {
        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        vm.prank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");

        MaliciousReentrancy malicious = new MaliciousReentrancy(address(proxy));
        vm.deal(address(malicious), 100 ether);

        vm.expectRevert(); // Will revert with ReentrancyGuard error
        malicious.attackBuy(TWIN_ID_1);
    }

    function testReentrancyProtectionOnSellShares() public {
        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        vm.startPrank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");
        vm.stopPrank();

        MaliciousReentrancy malicious = new MaliciousReentrancy(address(proxy));
        vm.deal(address(malicious), 100 ether);

        // First do a normal buy (no attack)
        uint256 buyCost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 5);
        vm.startPrank(address(malicious));
        malicious.normalBuy{value: buyCost}(TWIN_ID_1, 5);
        vm.stopPrank();

        assertEq(proxy.sharesBalance(TWIN_ID_1, address(malicious)), 5);

        vm.expectRevert(); // Will revert with ReentrancyGuard error
        malicious.attackSell(TWIN_ID_1);
    }

    // ============================================
    // DOS ATTACK TESTS
    // ============================================

    function testRevertingFeeDestinationBlocksBuying() public {
        RevertingContract reverter = new RevertingContract();

        vm.prank(owner);
        proxy.setFeeDestination(address(reverter));

        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        vm.prank(user1);
        vm.expectRevert("Unable to send funds");
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");
    }

    function testRevertingTwinOwnerDoesNotBlockBuying() public {
        RevertingContract reverter = new RevertingContract();

        vm.startPrank(admin);
        proxy.grantRole(proxy.CLAIM_OWNERSHIP_ROLE(), admin);
        vm.stopPrank();

        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        vm.startPrank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");
        vm.stopPrank();

        // Transfer ownership to reverting contract
        vm.startPrank(admin);
        proxy.claimOwnership(TWIN_ID_1, address(reverter));
        vm.stopPrank();

        // NOW BUYING IS NOT BLOCKED - This is what your fix achieved!
        vm.prank(user2);
        proxy.buyShares{value: 1 ether}(TWIN_ID_1, 3); 
        
        // Verify that the purchase was successful
        assertEq(proxy.sharesBalance(TWIN_ID_1, user2), 3);
        // Verify that fees are safely stored in claimableFees
        assertGt(proxy.claimableFees(address(reverter)), 0);
    }

    function testRevertingRecipientBlocksSelling() public {
        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        vm.prank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");

        vm.prank(user2);
        proxy.buyShares{value: 1 ether}(TWIN_ID_1, 5);

        // Set fee destination to reverting contract
        RevertingContract reverter = new RevertingContract();
        vm.prank(owner);
        proxy.setFeeDestination(address(reverter));

        // Selling is now blocked
        vm.prank(user2);
        vm.expectRevert("Unable to send funds");
        proxy.sellShares(TWIN_ID_1, 1, 0);
    }

    function testSmartContractCannotReceiveRefund() public {
        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        vm.startPrank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");
        vm.stopPrank();

        // Now a contract WITHOUT receive tries to BUY shares with excess payment
        NoReceiveContract noReceive = new NoReceiveContract();
        vm.deal(address(noReceive), 100 ether);

        uint256 buyCost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 5);

        vm.startPrank(address(noReceive));
        vm.expectRevert("Refund failed");
        proxy.buyShares{value: buyCost + 1 ether}(TWIN_ID_1, 5);
        vm.stopPrank();
    }

    // ============================================
    // EDGE CASES & INTEGRATION TESTS
    // ============================================

    function testMultipleUsersCanTradeSimultaneously() public {
        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        vm.prank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");

        vm.prank(user2);
        proxy.buyShares{value: 1 ether}(TWIN_ID_1, 3);

        vm.prank(user3);
        proxy.buyShares{value: 1 ether}(TWIN_ID_1, 2);

        vm.prank(user1);
        proxy.buyShares{value: 1 ether}(TWIN_ID_1, 1);

        assertEq(proxy.sharesSupply(TWIN_ID_1), 8);
        assertEq(proxy.sharesBalance(TWIN_ID_1, user1), 3);
        assertEq(proxy.sharesBalance(TWIN_ID_1, user2), 3);
        assertEq(proxy.sharesBalance(TWIN_ID_1, user3), 2);
    }

    function testComplexTradingSequence() public {
        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        vm.prank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");

        // User2 buys
        vm.prank(user2);
        proxy.buyShares{value: 1 ether}(TWIN_ID_1, 5);

        // User2 sells some
        vm.prank(user2);
        proxy.sellShares(TWIN_ID_1, 2, 0);

        // User3 buys
        vm.prank(user3);
        proxy.buyShares{value: 1 ether}(TWIN_ID_1, 3);

        // User1 sells
        vm.prank(user1);
        proxy.sellShares(TWIN_ID_1, 1, 0);

        // User2 buys more
        vm.prank(user2);
        proxy.buyShares{value: 1 ether}(TWIN_ID_1, 2);

        // Verify final state
        assertEq(proxy.sharesSupply(TWIN_ID_1), 9);
        assertEq(proxy.sharesBalance(TWIN_ID_1, user1), 1);
        assertEq(proxy.sharesBalance(TWIN_ID_1, user2), 5);
        assertEq(proxy.sharesBalance(TWIN_ID_1, user3), 3);
    }

    function testMultipleDigitalTwins() public {
        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);

        vm.prank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin1.com");

        vm.prank(user2);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_2, "https://twin2.com");

        vm.prank(user3);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_3, "https://twin3.com");

        assertTrue(proxy.digitalTwinExists(TWIN_ID_1));
        assertTrue(proxy.digitalTwinExists(TWIN_ID_2));
        assertTrue(proxy.digitalTwinExists(TWIN_ID_3));

        assertEq(proxy.digitalTwinIdToOwner(TWIN_ID_1), user1);
        assertEq(proxy.digitalTwinIdToOwner(TWIN_ID_2), user2);
        assertEq(proxy.digitalTwinIdToOwner(TWIN_ID_3), user3);
    }

    function testFeeChangesAffectFutureTrades() public {
        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        vm.prank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");

        uint256 priceBefore = proxy.getBuyPriceAfterFee(TWIN_ID_1, 5);

        vm.prank(owner);
        proxy.setProtocolFeePercent(0.05 ether); // 5%

        uint256 priceAfter = proxy.getBuyPriceAfterFee(TWIN_ID_1, 5);

        assertGt(priceAfter, priceBefore);
    }

    function testZeroFeesWork() public {
        vm.startPrank(owner);
        proxy.setProtocolFeePercent(0);
        proxy.setSubjectFeePercent(0);
        vm.stopPrank();

        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        vm.prank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");

        uint256 basePrice = proxy.getBuyPrice(TWIN_ID_1, 5);
        uint256 priceAfterFee = proxy.getBuyPriceAfterFee(TWIN_ID_1, 5);

        assertEq(basePrice, priceAfterFee);
    }

    function testHighFeesWork() public {
        vm.startPrank(owner);
        proxy.setProtocolFeePercent(0.01 ether); // 1%
        proxy.setSubjectFeePercent(0.05 ether); // 5%
        vm.stopPrank();

        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        vm.prank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");

        uint256 basePrice = proxy.getBuyPrice(TWIN_ID_1, 5);
        uint256 priceAfterFee = proxy.getBuyPriceAfterFee(TWIN_ID_1, 5);

        assertEq(priceAfterFee, basePrice + (basePrice * 6 / 100));
    }

    function testLargeAmountsWork() public {
        vm.startPrank(owner);
        proxy.setMinSharesToCreate(1);
        vm.stopPrank();

        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 1);
        vm.prank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");

        // Buy large amount
        vm.deal(user2, 1000 ether);
        uint256 largeBuyCost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 100);

        vm.prank(user2);
        proxy.buyShares{value: largeBuyCost}(TWIN_ID_1, 100);

        assertEq(proxy.sharesBalance(TWIN_ID_1, user2), 100);
    }

    function testContractBalanceTracking() public {
        uint256 contractBalanceBefore = address(proxy).balance;

        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        uint256 basePrice = proxy.getBuyPrice(TWIN_ID_1, 2);

        vm.startPrank(user1);
        // test refund of excess value
        proxy.createDigitalTwin{value: cost + 1 ether}(TWIN_ID_1, "https://twin.com");
        vm.stopPrank();

        // Contract should keep the base price (liquidity)
        assertEq(address(proxy).balance, contractBalanceBefore + basePrice);
    }

    // ============================================
    // UUPS-SPECIFIC TESTS
    // ============================================

    function testUUPSProxyDeployment() public view {
        // Verify proxy is correctly deployed
        address implementationAddress = Upgrades.getImplementationAddress(proxyAddress);
        assertTrue(implementationAddress != address(0));
        assertTrue(implementationAddress != proxyAddress);
    }

    function testImplementationCannotBeUsedDirectly() public {
        address implementationAddress = Upgrades.getImplementationAddress(proxyAddress);
        DigitalTwinSharesV1 implementation = DigitalTwinSharesV1(implementationAddress);

        // Cannot initialize implementation
        vm.expectRevert();
        implementation.initialize(attacker, attacker, attacker);

        // Cannot use implementation functions
        vm.prank(attacker);
        vm.expectRevert();
        implementation.createDigitalTwin{value: 1 ether}(TWIN_ID_1, "https://hacked.com");
    }

    function testUpgradePreservesStorage() public {
        // Create state in V1
        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        vm.prank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");

        vm.prank(user2);
        proxy.buyShares{value: 1 ether}(TWIN_ID_1, 5);

        // Store V1 state
        uint256 supply = proxy.sharesSupply(TWIN_ID_1);
        uint256 balance1 = proxy.sharesBalance(TWIN_ID_1, user1);
        uint256 balance2 = proxy.sharesBalance(TWIN_ID_1, user2);
        address twinOwner = proxy.digitalTwinIdToOwner(TWIN_ID_1);

        // Deploy new implementation and upgrade
        DigitalTwinSharesV1 newImpl = new DigitalTwinSharesV1();

        vm.prank(owner);
        proxy.upgradeToAndCall(address(newImpl), "");

        // Verify all storage is preserved after upgrade
        assertEq(proxy.sharesSupply(TWIN_ID_1), supply);
        assertEq(proxy.sharesBalance(TWIN_ID_1, user1), balance1);
        assertEq(proxy.sharesBalance(TWIN_ID_1, user2), balance2);
        assertEq(proxy.digitalTwinIdToOwner(TWIN_ID_1), twinOwner);
    }

    function testOnlyProxyOwnerCanUpgrade() public {
        // Deploy new implementation
        DigitalTwinSharesV1 newImpl = new DigitalTwinSharesV1();

        // Non-owner cannot upgrade
        vm.prank(user1);
        vm.expectRevert();
        proxy.upgradeToAndCall(address(newImpl), "");

        // Admin cannot upgrade (only owner can)
        vm.prank(admin);
        vm.expectRevert();
        proxy.upgradeToAndCall(address(newImpl), "");

        // Only owner can upgrade
        vm.prank(owner);
        proxy.upgradeToAndCall(address(newImpl), "");

        // Verify upgrade succeeded
        assertEq(Upgrades.getImplementationAddress(proxyAddress), address(newImpl));
    }

    function testProxyAddressStableAcrossUpgrade() public {
        address proxyAddressBefore = proxyAddress;

        // Deploy new implementation
        DigitalTwinSharesV1 newImpl = new DigitalTwinSharesV1();

        // Upgrade directly
        vm.prank(owner);
        proxy.upgradeToAndCall(address(newImpl), "");

        // Proxy address should remain the same
        assertEq(proxyAddress, proxyAddressBefore);

        // Verify implementation changed
        address newImplAddress = Upgrades.getImplementationAddress(proxyAddress);
        assertEq(newImplAddress, address(newImpl));
    }

    function testImplementationAddressChangesOnUpgrade() public {
        address implementationBefore = Upgrades.getImplementationAddress(proxyAddress);

        // Deploy new implementation
        DigitalTwinSharesV1 newImplementation = new DigitalTwinSharesV1();

        vm.prank(owner);
        proxy.upgradeToAndCall(address(newImplementation), "");

        address implementationAfter = Upgrades.getImplementationAddress(proxyAddress);

        // Implementation address should change
        assertEq(implementationAfter, address(newImplementation));
        assertTrue(implementationAfter != implementationBefore);
    }

    function testCannotUpgradeToNonUUPSContract() public {
        // Deploy a non-UUPS contract
        NonUUPSContract nonUUPS = new NonUUPSContract();

        vm.prank(owner);
        vm.expectRevert();
        proxy.upgradeToAndCall(address(nonUUPS), "");
    }

    function testCannotUpgradeToZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert();
        proxy.upgradeToAndCall(address(0), "");
    }
}

// ============================================
// MALICIOUS CONTRACTS FOR TESTING
// ============================================

contract MaliciousReentrancy {
    DigitalTwinSharesV1 public target;
    bool public attacking;
    bool public attackOnReceive;

    constructor(address _target) {
        target = DigitalTwinSharesV1(_target);
    }

    receive() external payable {
        if (attackOnReceive && !attacking) {
            attacking = true;
            target.buyShares{value: 0.1 ether}(bytes16(uint128(1)), 1);
        }
    }

    function attackBuy(bytes16 twinId) external {
        attacking = false;
        attackOnReceive = true; // Enable attack
        uint256 cost = target.getBuyPriceAfterFee(twinId, 1);
        target.buyShares{value: cost + 1 ether}(twinId, 1);
    }

    function attackSell(bytes16 twinId) external {
        attacking = false;
        attackOnReceive = true; // Enable attack
        target.sellShares(twinId, 1, 0);
    }

    function normalBuy(bytes16 twinId, uint256 amount) external payable {
        attackOnReceive = false; // Don't attack during normal operations
        target.buyShares{value: msg.value}(twinId, amount);
    }
}

contract RevertingContract {
    receive() external payable {
        revert("I always revert");
    }
}

function testWithdrawFees() public {
        uint256 cost = proxy.getBuyPriceAfterFee(TWIN_ID_1, 2);
        vm.prank(user1);
        proxy.createDigitalTwin{value: cost}(TWIN_ID_1, "https://twin.com");
        
        uint256 claimable = proxy.claimableFees(user1);
        uint256 balanceBefore = user1.balance;

        vm.prank(user1);
        proxy.withdrawFees();

        assertEq(user1.balance, balanceBefore + claimable, "Full amount should be withdrawn");
        assertEq(proxy.claimableFees(user1), 0, "Claimable balance should be reset to zero");
    }
}

contract NoReceiveContract {}

contract NonUUPSContract {
    function someFunction() public pure returns (uint256) {
        return 42;
    }
}
