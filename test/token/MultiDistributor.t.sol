// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "src/contracts/token/MultiDistributor.sol";
import "test/shared/mocks/MockERC20.sol";

/**
 * @dev Testing claiming flows for MultiDistributor contract
 */
contract MultiDistributorTest {
  uint public constant DEFAULT_MINT = 10_000e18;

  address alice = address(0xaa);
  address bob = address(0xbb);
  address charlie = address(0xcc);
  address whitelist = address(0xdd);

  MultiDistributor tokenDistributor;
  MockERC20 lyra;
  MockERC20 op;

  function setUp() public {
    console.log("SETUP");
    tokenDistributor = new MultiDistributor();

    lyra = new MockERC20("LYRA", "LYRA");
    op = new MockERC20("OP", "OP");
    
    lyra.mint(tokenDistributor, DEFAULT_MINT);
    op.mint(tokenDistributor, DEFAULT_MINT);

    tokenDistributor.setWhitelistAddress(whitelist, true);
  }

  function testCanChangeWhitelist() public {
    assertEq(tokenDistributor.whitelisted(whitelist), true);
    tokenDistributor.setWhitelistAddress(whitelist, false);
    assertEq(tokenDistributor.whitelisted(whitelist), false);
  }

  function testCanAddToClaims() public {
    vm.startPrank(whitelist);
    MultiDistributor.UserTokenAmounts[] memory claimsToAdd = _createClaims(1000e18);

    tokenDistributor.addToClaims(claimsToAdd, block.timestamp, "");

    MultiDistributor.UserTokenAmounts memory aliceClaim = tokenDistributor.userToClaimIds(alice, 0);
    console.log("aliceClaim", aliceClaim.amount);
  }

  function testCannotAddToClaims() public {
    vm.startPrank(alice);
    MultiDistributor.UserTokenAmounts[] memory claimsToAdd = _createClaims(1000e18);

    vm.expectRevert(abi.encodeWithSelector(MultiDistributor.NotWhitelisted, alice));
    tokenDistributor.addToClaims(claimsToAdd, block.timestamp, "");
  }

  function testCanClaimIfApproved() public {
    console.log("Can claim");
  }


  function _createClaims(uint amount) internal returns (MultiDistributor.UserTokenAmounts[] memory claimsToAdd) {
    MultiDistributor.UserTokenAmounts[] memory claimsToAdd; 
    MultiDistributor.UserTokenAmounts memory lyraClaim = MultiDistributor.UserTokenAmounts(alice, lyra, amount);
    MultiDistributor.UserTokenAmounts memory opClaim = MultiDistributor.UserTokenAmounts(alice, op, amount);

    claimsToAdd[0] = lyraClaim;
    claimsToAdd[1] = opClaim;
  }
}
