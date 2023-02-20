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
  uint public constant DEFAULT_MINT = 10_000e18;

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
    vm.startPrank(whitelist);
    uint lyraAmount = 1000e18;
    uint opAmount = 500e18;
    MultiDistributor.UserTokenAmounts[] memory claimsToAdd = _createClaims(alice, lyraAmount, opAmount);

    tokenDistributor.addToClaims(claimsToAdd, block.timestamp, "");

    (IERC20 token, uint amount, bool approved) = tokenDistributor.userToClaimIds(alice, 0);
    (IERC20 token1, uint amount1, bool approved1) = tokenDistributor.userToClaimIds(alice, 1);
    assertEq(amount, lyraAmount);
    assertEq(approved, false);
    assertEq(amount1, opAmount);
    assertEq(approved1, false);
  }

  // Check not whitelisted addresses CANNOT add to claims
  function testCannotAddToClaims() public {
    vm.startPrank(alice);
    MultiDistributor.UserTokenAmounts[] memory claimsToAdd = _createClaims(alice, 1000e18, 1000e18);

    // Alice is not whitelisted
    vm.expectRevert(abi.encodeWithSelector(MultiDistributor.NotWhitelisted.selector, alice));
    tokenDistributor.addToClaims(claimsToAdd, block.timestamp, "");
  }

  // Check user can claim their approved claimId
  function testCanClaimIfApproved() public {
    vm.startPrank(whitelist);
    uint lyraAmount = 1000e18;
    uint opAmount = 500e18;
    MultiDistributor.UserTokenAmounts[] memory claimsToAdd = _createClaims(alice, lyraAmount, opAmount);

    tokenDistributor.addToClaims(claimsToAdd, block.timestamp, "");
    vm.stopPrank();

    MultiDistributor.UserAndClaimId[] memory ids = new MultiDistributor.UserAndClaimId[](2);
    ids[0].user = alice;
    ids[0].claimId = 0;
    ids[1].user = alice;
    ids[1].claimId = 1;

    tokenDistributor.approveClaims(ids, true);

    vm.startPrank(alice);

    tokenDistributor.claim(ids);
    uint lyraBal = lyra.balanceOf(alice);
    uint opBal = op.balanceOf(alice);

    assertEq(lyraBal, lyraAmount);
    assertEq(opBal, opAmount);
  }

  // Check user CANNOT claim their unapproved claimId
  function testCannotClaimIfNotApproved() public {
    vm.startPrank(whitelist);
    uint lyraAmount = 1000e18;
    uint opAmount = 500e18;
    MultiDistributor.UserTokenAmounts[] memory claimsToAdd = _createClaims(alice, lyraAmount, opAmount);

    tokenDistributor.addToClaims(claimsToAdd, block.timestamp, "");
    vm.stopPrank();

    // Claims are not approved
    MultiDistributor.UserAndClaimId[] memory ids = new MultiDistributor.UserAndClaimId[](2);
    ids[0].user = alice;
    ids[0].claimId = 0;
    ids[1].user = alice;
    ids[1].claimId = 1;

    vm.startPrank(alice);
    vm.expectRevert(abi.encodeWithSelector(MultiDistributor.ClaimNotApproved.selector, 0));
    tokenDistributor.claim(ids);
  }

  // Allows you to claim the same claimId multiple times but just returns 0
  function testCanClaimSameAgain() public {
    vm.startPrank(whitelist);
    uint lyraAmount = 1000e18;
    uint opAmount = 500e18;
    MultiDistributor.UserTokenAmounts[] memory claimsToAdd = _createClaims(alice, lyraAmount, opAmount);

    tokenDistributor.addToClaims(claimsToAdd, block.timestamp, "");
    vm.stopPrank();

    MultiDistributor.UserAndClaimId[] memory ids = new MultiDistributor.UserAndClaimId[](2);
    ids[0].user = alice;
    ids[0].claimId = 0;
    ids[1].user = alice;
    ids[1].claimId = 1;

    tokenDistributor.approveClaims(ids, true);

    vm.startPrank(alice);

    tokenDistributor.claim(ids);
    uint lyraBal = lyra.balanceOf(alice);
    uint opBal = op.balanceOf(alice);

    assertEq(lyraBal, lyraAmount);
    assertEq(opBal, opAmount);

    // Able to claim again however balance does NOT increase
    tokenDistributor.claim(ids);
    lyraBal = lyra.balanceOf(alice);
    opBal = op.balanceOf(alice);

    assertEq(lyraBal, lyraAmount);
    assertEq(opBal, opAmount);
  }

  // Owner can remove claim
  function testCanRemoveClaim() public {
    vm.startPrank(whitelist);
    uint lyraAmount = 1000e18;
    uint opAmount = 500e18;
    MultiDistributor.UserTokenAmounts[] memory claimsToAdd = _createClaims(alice, lyraAmount, opAmount);

    tokenDistributor.addToClaims(claimsToAdd, block.timestamp, "");

    (IERC20 token, uint amount, bool approved) = tokenDistributor.userToClaimIds(alice, 0);
    (IERC20 token1, uint amount1, bool approved1) = tokenDistributor.userToClaimIds(alice, 1);
    assertEq(amount, lyraAmount);
    assertEq(amount1, opAmount);

    MultiDistributor.UserAndClaimId[] memory ids = new MultiDistributor.UserAndClaimId[](2);
    ids[0].user = alice;
    ids[0].claimId = 0;
    ids[1].user = alice;
    ids[1].claimId = 1;

    vm.stopPrank();
    tokenDistributor.removeClaims(ids);

    (token, amount, approved) = tokenDistributor.userToClaimIds(alice, 0);
    (token1, amount1, approved1) = tokenDistributor.userToClaimIds(alice, 1);
    assertEq(amount, 0);
    assertEq(amount1, 0);
  }

  // Not whitelisted cannot remove claim
  function testCannotRemoveClaimByWhitelisted() public {
    vm.startPrank(whitelist);
    uint lyraAmount = 1000e18;
    uint opAmount = 500e18;
    MultiDistributor.UserTokenAmounts[] memory claimsToAdd = _createClaims(alice, lyraAmount, opAmount);

    tokenDistributor.addToClaims(claimsToAdd, block.timestamp, "");

    (IERC20 token, uint amount, bool approved) = tokenDistributor.userToClaimIds(alice, 0);
    (IERC20 token1, uint amount1, bool approved1) = tokenDistributor.userToClaimIds(alice, 1);
    assertEq(amount, lyraAmount);
    assertEq(amount1, opAmount);

    MultiDistributor.UserAndClaimId[] memory ids = new MultiDistributor.UserAndClaimId[](2);
    ids[0].user = alice;
    ids[0].claimId = 0;
    ids[1].user = alice;
    ids[1].claimId = 1;

    // Reverts because this contract is not whitelisted
    vm.expectRevert(bytes("Ownable: caller is not the owner"));
    tokenDistributor.removeClaims(ids);
  }

  // Not owner cannot remove claim
  function testCannotRemoveClaimNotOwner() public {
    vm.startPrank(whitelist);
    uint lyraAmount = 1000e18;
    uint opAmount = 500e18;
    MultiDistributor.UserTokenAmounts[] memory claimsToAdd = _createClaims(alice, lyraAmount, opAmount);

    tokenDistributor.addToClaims(claimsToAdd, block.timestamp, "");

    (IERC20 token, uint amount, bool approved) = tokenDistributor.userToClaimIds(alice, 0);
    (IERC20 token1, uint amount1, bool approved1) = tokenDistributor.userToClaimIds(alice, 1);
    assertEq(amount, lyraAmount);
    assertEq(amount1, opAmount);

    MultiDistributor.UserAndClaimId[] memory ids = new MultiDistributor.UserAndClaimId[](2);
    ids[0].user = alice;
    ids[0].claimId = 0;
    ids[1].user = alice;
    ids[1].claimId = 1;

    vm.stopPrank();
    vm.startPrank(alice);

    // Reverts because this contract is not whitelisted
    vm.expectRevert(bytes("Ownable: caller is not the owner"));
    tokenDistributor.removeClaims(ids);
  }

  function testCanGetClaimableForAddress() public {
    vm.startPrank(whitelist);
    uint lyraAmount = 1000e18;
    uint opAmount = 500e18;
    MultiDistributor.UserTokenAmounts[] memory claimsToAdd = _createClaims(alice, lyraAmount, opAmount);

    tokenDistributor.addToClaims(claimsToAdd, block.timestamp, "");

    uint[] memory ids = new uint[](2);
    ids[0] = 0;
    ids[1] = 1;
    MultiDistributor.UserClaim[] memory claimable = tokenDistributor.getClaimableForAddress(alice, ids);

    // Should be 0 because not approved
    assertEq(claimable[0].amount, 0);
    assertEq(claimable[1].amount, 0);

    vm.stopPrank();
    MultiDistributor.UserAndClaimId[] memory approveIds = new MultiDistributor.UserAndClaimId[](2);
    approveIds[0].user = alice;
    approveIds[0].claimId = 0;
    approveIds[1].user = alice;
    approveIds[1].claimId = 1;

    tokenDistributor.approveClaims(approveIds, true);

    claimable = tokenDistributor.getClaimableForAddress(alice, ids);

    // Should be show amounts now that we have approved
    assertEq(claimable[0].amount, lyraAmount);
    assertEq(claimable[1].amount, opAmount);
  }

  // Returns 0 after already claimed
  function testCannnotGetClaimableForAddress() public {
    vm.startPrank(whitelist);
    uint lyraAmount = 1000e18;
    uint opAmount = 500e18;
    MultiDistributor.UserTokenAmounts[] memory claimsToAdd = _createClaims(alice, lyraAmount, opAmount);

    tokenDistributor.addToClaims(claimsToAdd, block.timestamp, "");

    uint[] memory ids = new uint[](2);
    ids[0] = 0;
    ids[1] = 1;
    MultiDistributor.UserClaim[] memory claimable = tokenDistributor.getClaimableForAddress(alice, ids);

    // Should be 0 because not approved
    assertEq(claimable[0].amount, 0);
    assertEq(claimable[1].amount, 0);

    vm.stopPrank();
    MultiDistributor.UserAndClaimId[] memory approveIds = new MultiDistributor.UserAndClaimId[](2);
    approveIds[0].user = alice;
    approveIds[0].claimId = 0;
    approveIds[1].user = alice;
    approveIds[1].claimId = 1;

    tokenDistributor.approveClaims(approveIds, true);

    vm.startPrank(alice);
    tokenDistributor.claim(approveIds);

    claimable = tokenDistributor.getClaimableForAddress(alice, ids);

    // Should return 0 because already claimed
    assertEq(claimable[0].amount, 0);
    assertEq(claimable[1].amount, 0);
  }

  function _createClaims(address user, uint lyraAmount, uint opAmount)
    internal
    returns (MultiDistributor.UserTokenAmounts[] memory claimsToAdd)
  {
    claimsToAdd = new MultiDistributor.UserTokenAmounts[](2);
    MultiDistributor.UserTokenAmounts memory lyraClaim = MultiDistributor.UserTokenAmounts(user, lyra, lyraAmount);
    MultiDistributor.UserTokenAmounts memory opClaim = MultiDistributor.UserTokenAmounts(user, op, opAmount);

    claimsToAdd[0] = lyraClaim;
    claimsToAdd[1] = opClaim;
  }
}
