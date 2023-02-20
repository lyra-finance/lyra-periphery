// SPDX-License-Identifier: ISC
pragma solidity ^0.8.13;
pragma abicoder v2;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title Token Distributor contract.
 * @dev   Whitelisted addresses can create claims for tokens.
 *        Contract owner can approve / remove these claims.
 *
 * @author Lyra
 */

contract MultiDistributor is Ownable {
  // Details of created claims
  struct UserClaim {
    IERC20 token;
    uint amount;
    bool approved;
  }

  // Details for approving, removing claiming claims
  struct UserAndClaimId {
    address user;
    uint claimId;
  }

  // Details for adding new claims
  struct UserTokenAmounts {
    address user;
    IERC20 token;
    uint amount;
  }

  // Claim Ids
  uint nextId;

  mapping(address => bool) public whitelisted; // Whitelisted addresses approved for creating claims
  mapping(address => mapping(uint => UserClaim)) public userToClaimIds; // User -> Id -> Claims
  mapping(address => mapping(IERC20 => uint)) public totalClaimed; // User -> Token -> Amount claimed

  /////////////////////
  //   Constructor   //
  /////////////////////

  constructor() Ownable() {}

  //////////////////////////////
  //   Owner-only Functions   //
  //////////////////////////////

  /**
   * @notice Setter to whitelist an address to create claims.
   *
   * @param _user The address to be added or removed.
   * @param _whitelist Boolean on whether the address is being added or removed.
   */
  function setWhitelistAddress(address _user, bool _whitelist) external onlyOwner {
    whitelisted[_user] = _whitelist;
    emit WhitelistAddressSet(_user, _whitelist);
  }

  /**
   * @notice Allows owner to approve or unapprove claimIds.
   *
   * @param claimIds The list of claimIds to approve or unapprove
   * @param approve Bool on whether the ids are being approved or not
   */
  function approveClaims(UserAndClaimId[] memory claimIds, bool approve) external onlyOwner {
    for (uint i = 0; i < claimIds.length; i++) {
      userToClaimIds[claimIds[i].user][claimIds[i].claimId].approved = approve;

      emit ClaimApproved(claimIds[i].user, claimIds[i].claimId);
    }
  }

  /**
   * @notice Allows whitelisted addresses to remove claims.
   * @param removeList List of user and claimIds to remove
   */
  function removeClaims(UserAndClaimId[] memory removeList) external onlyOwner {
    for (uint i = 0; i < removeList.length; i++) {
      uint removedAmount = userToClaimIds[removeList[i].user][removeList[i].claimId].amount;
      userToClaimIds[removeList[i].user][removeList[i].claimId].amount = 0;

      emit ClaimRemoved(
        removeList[i].user,
        removeList[i].claimId,
        userToClaimIds[removeList[i].user][removeList[i].claimId].token,
        removedAmount
        );
    }
  }

  //////////////////////////////////
  //   Whitelist-only Functions   //
  //////////////////////////////////

  /**
   * @notice Allows whitelisted addresses to create new claims.
   *
   * @param claimsToAdd List of user, tokens and amounts to create claims
   * @param epochTimestamp The timestamp for the epoch
   * @param tag Data relating to the claim
   */
  function addToClaims(UserTokenAmounts[] memory claimsToAdd, uint epochTimestamp, string memory tag) external {
    if (whitelisted[msg.sender] != true) revert NotWhitelisted(msg.sender);

    for (uint i = 0; i < claimsToAdd.length; i++) {
      UserTokenAmounts memory claimToAdd = claimsToAdd[i];
      UserClaim memory newClaim = UserClaim(claimToAdd.token, claimToAdd.amount, false);
      userToClaimIds[claimToAdd.user][nextId] = newClaim;
      nextId++;

      emit ClaimAdded(claimToAdd.token, claimToAdd.user, newClaim.amount, nextId, epochTimestamp, tag);
    }
  }

  ////////////////////////////
  //   External Functions   //
  ////////////////////////////

  /**
   * @notice Allows user to redeem a list of claimIds.
   * @param claimList List of claimIds to claim
   */
  function claim(UserAndClaimId[] memory claimList) external {
    for (uint i = 0; i < claimList.length; i++) {
      uint claimId = claimList[i].claimId;

      UserClaim memory toClaim = userToClaimIds[msg.sender][claimId];

      if (toClaim.approved != true) revert ClaimNotApproved(claimId);
      uint balanceToClaim = toClaim.amount;

      if (balanceToClaim == 0) {
        continue;
      }

      userToClaimIds[msg.sender][claimId].amount = 0;
      totalClaimed[msg.sender][toClaim.token] += balanceToClaim;

      toClaim.token.transfer(msg.sender, balanceToClaim);
      emit Claimed(toClaim.token, msg.sender, claimId, balanceToClaim);
    }
  }

  /**
   * @notice Returns approved pending claimIds for a user.
   * @param user User claims to check
   * @param claimIds The list of claimIds to claim
   */
  function getClaimableForAddress(address user, uint[] memory claimIds)
    external
    view
    returns (UserClaim[] memory claimable)
  {
    claimable = new UserClaim[](claimIds.length);

    for (uint i = 0; i < claimIds.length; i++) {
      UserClaim memory potentialClaim = userToClaimIds[user][claimIds[i]];

      if (potentialClaim.amount > 0 && potentialClaim.approved == true) {
        claimable[i] = UserClaim(potentialClaim.token, potentialClaim.amount, potentialClaim.approved);
      }
    }
  }

  ////////////
  // Events //
  ////////////

  event WhitelistAddressSet(address user, bool whitelisted);

  event Claimed(IERC20 indexed rewardToken, address indexed claimer, uint indexed claimId, uint amount);

  event ClaimAdded(
    IERC20 rewardToken,
    address indexed claimer,
    uint amount,
    uint indexed claimId,
    uint indexed epochTimestamp,
    string tag
  );

  event ClaimRemoved(address indexed claimer, uint indexed claimId, IERC20 indexed rewardToken, uint amount);

  event ClaimApproved(address indexed claimer, uint indexed claimId);

  ////////////
  // Errors //
  ////////////

  error NotWhitelisted(address user);

  error ClaimNotApproved(uint claimId);
}
