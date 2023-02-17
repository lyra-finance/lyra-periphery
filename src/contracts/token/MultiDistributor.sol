// SPDX-License-Identifier: ISC
pragma solidity ^0.8.13;
pragma abicoder v2;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title Token Distributor contract.
 * @dev   Whitelisted addresses can create / remove claims for tokens.
 *        Contract owner can approve these claims.
 *
 * @author Lyra
 */

contract MultiDistributor is Ownable {
  struct UserClaim {
    address user;
    IERC20 token;
    uint amount;
    bool approved;
  }

  struct UserAndClaimId {
    address user;
    uint claimId;
  }

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
   * @notice Whitelists the address to create claims.
   *
   * @param _user The address to be added or removed.
   * @param _whitelist Boolean on whether the address is being added or removed.
   */
  function setWhitelistAddress(address _user, bool _whitelist) external onlyOwner {
    whitelisted[_user] = _whitelist;
    emit WhitelistAddressSet(_user, _whitelist);
  }

  /**
   * @notice Whitelists the address to create claims.
   *
   * @param claimIds The list of claimIds to approve or unapprove
   * @param approve Bool on whether the ids are being approved or not 
   */
  function approveClaims(UserAndClaimId[] memory claimIds, bool approve) external onlyOwner {
    for (uint i = 0; i < claimIds.length; i++) {
      userToClaimIds[claimIds[i].user][claimIds[i].claimId].approved = approve;
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
  function addToClaims(UserTokenAmounts[] memory claimsToAdd, uint epochTimestamp, string memory tag)
    external
  {
    if (whitelisted[msg.sender] != true) revert NotWhitelisted(msg.sender);

    for (uint i = 0; i < claimsToAdd.length; i++) {
      UserTokenAmounts memory claimToAdd = claimsToAdd[i];
      UserClaim memory newClaim = UserClaim(claimToAdd.user, claimToAdd.token, claimToAdd.amount, false);
      userToClaimIds[claimToAdd.user][nextId] = newClaim;
      nextId++;

      emit ClaimAdded(claimToAdd.token, newClaim.user, newClaim.amount, nextId, epochTimestamp, tag);
    }
  }

  /**
   * @notice Allows whitelisted addresses to remove claims.
   * @param removeList List of user and claimIds to remove
   */
  function removeClaims(UserAndClaimId[] memory removeList) external {
    if (whitelisted[msg.sender] != true) revert NotWhitelisted(msg.sender);

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

  ////////////////////////////
  //   External Functions   //
  ////////////////////////////

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

  function getClaimableForAddress(address user, uint[] memory claimIds) 
    external
    view
    returns (UserTokenAmounts[] memory claimable)
  {
    claimable = new UserTokenAmounts[](claimIds.length);

    for (uint i = 0; i < claimIds.length; i++) {
      UserClaim memory potentialClaim = userToClaimIds[user][claimIds[i]];

      if (potentialClaim.amount > 0 && potentialClaim.approved == true) {
        claimable[i] = UserTokenAmounts(user, potentialClaim.token, potentialClaim.amount);
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

  ////////////
  // Errors //
  ////////////

  error NotWhitelisted(address user);
  
  error ClaimNotApproved(uint claimId);
}
