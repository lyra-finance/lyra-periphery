// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "src/contracts/token/MultiDistributor.sol";
import "test/shared/mocks/MockERC20.sol";

/**
 * @dev Testing claiming flows for MultiDistributor contract
 */
contract MultiDistributorTest is Test {
  uint public constant DEFAULT_MINT = 1000000e18;

  address alice = address(0xaa);
  address bob = address(0xbb);
  address charlie = address(0xcc);
  address whitelist = address(0xdd);

  MultiDistributor tokenDistributor;
  MockERC20 lyra;
  MockERC20 op;

  function setUp() public {
    tokenDistributor = new MultiDistributor();

    lyra = new MockERC20("LYRA", "LYRA");
    op = new MockERC20("OP", "OP");

    lyra.mint(address(tokenDistributor), DEFAULT_MINT);
    op.mint(address(tokenDistributor), DEFAULT_MINT);

    tokenDistributor.setWhitelistAddress(whitelist, true);
  }

  function testCanChangeWhitelist() public {
    assertEq(tokenDistributor.whitelisted(whitelist), true);
    tokenDistributor.setWhitelistAddress(whitelist, false);
    assertEq(tokenDistributor.whitelisted(whitelist), false);
  }

  // Check whitelisted addresses can add to claims
  function testCanAddToClaims() public {
    uint lyraAmount = 1000e18;
    uint opAmount = 500e18;

    address[] memory users = new address[](3);
    users[0] = alice;
    users[1] = bob;
    users[2] = alice;

    // Creates two claims for alice and one claim for bob per token
    _createAndAddClaims(users, lyraAmount, opAmount);

    assertEq(tokenDistributor.amountToClaim(1, alice), lyraAmount * 2);
    assertEq(tokenDistributor.amountToClaim(1, bob), lyraAmount);
    assertEq(tokenDistributor.amountToClaim(2, alice), opAmount * 2);
    assertEq(tokenDistributor.amountToClaim(2, bob), opAmount);
  }

  // Check not whitelisted addresses CANNOT add to claims
  function testCannotAddToClaims() public {
    vm.startPrank(alice);

    uint[] memory lyraClaims = new uint[](2);
    lyraClaims[0] = 1000e18;
    lyraClaims[1] = 1000e18;

    address[] memory users = new address[](2);
    users[0] = alice;
    users[1] = alice;

    // Alice is not whitelisted
    vm.expectRevert(abi.encodeWithSelector(MultiDistributor.MD_NotWhitelisted.selector, alice));
    tokenDistributor.addToClaims(lyraClaims, users, lyra, block.timestamp, "");
  }

  // Check function reverts if the input array lengths do not match
  function testCannotHaveDifferentArrayInputLength() public {
    vm.startPrank(whitelist);

    uint[] memory lyraClaims = new uint[](2);
    lyraClaims[0] = 1000e18;
    lyraClaims[1] = 1000e18;

    address[] memory users = new address[](3);
    users[0] = alice;
    users[1] = alice;
    users[2] = alice;

    // Array lengths do not match
    vm.expectRevert(
      abi.encodeWithSelector(MultiDistributor.MD_InvalidArrayLength.selector, lyraClaims.length, users.length)
    );
    tokenDistributor.addToClaims(lyraClaims, users, lyra, block.timestamp, "");
  }

  // Check user can claim their approved claimId
  function testCanClaimIfApproved() public {
    uint lyraAmount = 1000e18;
    uint opAmount = 500e18;

    address[] memory users = new address[](3);
    users[0] = alice;
    users[1] = bob;
    users[2] = alice;

    _createAndAddClaims(users, lyraAmount, opAmount);
    (, bool approved) = tokenDistributor.batchApprovals(0);
    (, bool approved1) = tokenDistributor.batchApprovals(1);

    // Approvals should be false
    assertEq(approved, false);
    assertEq(approved1, false);

    uint[] memory ids = new uint[](2);
    ids[0] = 1;
    ids[1] = 2;

    // Approve which should allow alice to claim
    tokenDistributor.approveClaims(ids, true);

    vm.startPrank(alice);

    tokenDistributor.claim(ids);
    uint lyraBal = lyra.balanceOf(alice);
    uint opBal = op.balanceOf(alice);

    assertEq(lyraBal, lyraAmount * 2);
    assertEq(opBal, opAmount * 2);
  }

  // Check user CANNOT claim their unapproved claimId
  function testCannotClaimIfNotApproved() public {
    uint lyraAmount = 1000e18;
    uint opAmount = 500e18;

    address[] memory users = new address[](3);
    users[0] = alice;
    users[1] = bob;
    users[2] = alice;

    _createAndAddClaims(users, lyraAmount, opAmount);

    (, bool approved) = tokenDistributor.batchApprovals(0);
    (, bool approved1) = tokenDistributor.batchApprovals(1);

    // Approvals should be false
    assertEq(approved, false);
    assertEq(approved1, false);

    uint[] memory ids = new uint[](2);
    ids[0] = 1;
    ids[1] = 2;

    // batchIds are not approved
    // tokenDistributor.approveClaims(ids, true);

    vm.startPrank(alice);

    // Batch not approved so claim should revert
    vm.expectRevert(abi.encodeWithSelector(MultiDistributor.MD_BatchNotApproved.selector, ids[0]));
    tokenDistributor.claim(ids);
  }

  // Allows you to claim the same claimId multiple times but just returns 0
  function testCanClaimSameAgain() public {
    uint lyraAmount = 1000e18;
    uint opAmount = 500e18;

    address[] memory users = new address[](3);
    users[0] = alice;
    users[1] = bob;
    users[2] = alice;

    _createAndAddClaims(users, lyraAmount, opAmount);

    uint[] memory ids = new uint[](2);
    ids[0] = 1;
    ids[1] = 2;

    tokenDistributor.approveClaims(ids, true);

    vm.startPrank(alice);

    // Claim first time, should receive tokens
    tokenDistributor.claim(ids);
    uint lyraBal = lyra.balanceOf(alice);
    uint opBal = op.balanceOf(alice);

    assertEq(lyraBal, lyraAmount * 2);
    assertEq(opBal, opAmount * 2);

    // Able to claim again however balance does NOT increase
    tokenDistributor.claim(ids);
    lyraBal = lyra.balanceOf(alice);
    opBal = op.balanceOf(alice);

    assertEq(lyraBal, lyraAmount * 2);
    assertEq(opBal, opAmount * 2);
  }

  function testCanGetClaimableAmountForUser() public {
    uint lyraAmount = 1000e18;
    uint opAmount = 500e18;

    address[] memory users = new address[](3);
    users[0] = alice;
    users[1] = bob;
    users[2] = alice;

    _createAndAddClaims(users, lyraAmount, opAmount);

    uint[] memory ids = new uint[](2);
    ids[0] = 1;
    ids[1] = 2;
    uint lyraClaimable = tokenDistributor.getClaimableAmountForUser(ids, alice, lyra);
    uint opClaimAble = tokenDistributor.getClaimableAmountForUser(ids, alice, op);

    // Should be 0 because not approved
    assertEq(lyraClaimable, 0);
    assertEq(opClaimAble, 0);

    tokenDistributor.approveClaims(ids, true);

    lyraClaimable = tokenDistributor.getClaimableAmountForUser(ids, alice, lyra);
    opClaimAble = tokenDistributor.getClaimableAmountForUser(ids, alice, op);

    // Assert for Alice
    assertEq(lyraClaimable, lyraAmount * 2);
    assertEq(opClaimAble, opAmount * 2);

    lyraClaimable = tokenDistributor.getClaimableAmountForUser(ids, bob, lyra);
    opClaimAble = tokenDistributor.getClaimableAmountForUser(ids, bob, op);

    // Assert for Bob
    assertEq(lyraClaimable, lyraAmount);
    assertEq(opClaimAble, opAmount);
  }

  // Returns 0 after already claimed
  function testCannnotGetClaimableAmountForUser() public {
    uint lyraAmount = 1000e18;
    uint opAmount = 500e18;

    address[] memory users = new address[](3);
    users[0] = alice;
    users[1] = bob;
    users[2] = alice;

    _createAndAddClaims(users, lyraAmount, opAmount);

    uint[] memory ids = new uint[](2);
    ids[0] = 1;
    ids[1] = 2;

    tokenDistributor.approveClaims(ids, true);

    vm.startPrank(alice);
    tokenDistributor.claim(ids);

    uint lyraBal = lyra.balanceOf(alice);
    uint opBal = op.balanceOf(alice);

    // Assert that tokens are claimed
    assertEq(lyraBal, lyraAmount * 2);
    assertEq(opBal, opAmount * 2);

    uint lyraClaimable = tokenDistributor.getClaimableAmountForUser(ids, alice, lyra);
    uint opClaimAble = tokenDistributor.getClaimableAmountForUser(ids, alice, op);

    // Claimable should be 0
    assertEq(lyraClaimable, 0);
    assertEq(opClaimAble, 0);
  }

  function testCanGetClaimableIdsForUser() public {
    uint lyraAmount = 1000e18;
    uint opAmount = 500e18;

    address[] memory users = new address[](3);
    users[0] = alice;
    users[1] = bob;
    users[2] = alice;

    _createAndAddClaims(users, lyraAmount, opAmount);

    uint[] memory ids = new uint[](3);
    ids[0] = 1;
    ids[1] = 2;
    ids[2] = 3;
    uint[] memory aliceIds = tokenDistributor.getClaimableIdsForUser(ids, alice);

    // Should be 0 because not approved
    assertEq(aliceIds[0], 0);
    assertEq(aliceIds[1], 0);
    assertEq(aliceIds[2], 0);

    // Approve only the first claim
    ids[1] = 0;
    ids[2] = 0;
    tokenDistributor.approveClaims(ids, true);
    aliceIds = tokenDistributor.getClaimableIdsForUser(ids, alice);

    assertEq(aliceIds[0], 1);
    assertEq(aliceIds[1], 0);
    assertEq(aliceIds[2], 0);

    // Approve the other claims
    ids[1] = 2;
    ids[2] = 3;
    tokenDistributor.approveClaims(ids, true);
    aliceIds = tokenDistributor.getClaimableIdsForUser(ids, alice);

    assertEq(aliceIds[0], 1);
    assertEq(aliceIds[1], 2);

    // Empty claim amount is not claimable
    assertEq(aliceIds[2], 0);
  }

  function _createAndAddClaims(address[] memory users, uint lyraAmount, uint opAmount) internal {
    uint[] memory lyraClaims = new uint[](3);
    lyraClaims[0] = lyraAmount;
    lyraClaims[1] = lyraAmount;
    lyraClaims[2] = lyraAmount;

    uint[] memory opClaims = new uint[](3);
    opClaims[0] = opAmount;
    opClaims[1] = opAmount;
    opClaims[2] = opAmount;

    uint[] memory emptyClaims = new uint[](3);
    emptyClaims[0] = 0;
    emptyClaims[1] = 0;
    emptyClaims[2] = 0;

    vm.startPrank(whitelist);
    tokenDistributor.addToClaims(lyraClaims, users, lyra, block.timestamp, "");
    tokenDistributor.addToClaims(opClaims, users, op, block.timestamp, "");
    tokenDistributor.addToClaims(emptyClaims, users, op, block.timestamp, "");
    vm.stopPrank();
  }
}
