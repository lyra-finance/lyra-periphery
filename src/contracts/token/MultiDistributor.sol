// SPDX-License-Identifier: ISC
pragma solidity ^0.8.13;
pragma abicoder v2;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title Token Distributor contract.
 * @dev   Whitelisted addresses can create batched claims for tokens.
 *        Contract owner can approve / remove these claims.
 *
 * @author Lyra
 */

contract MultiDistributor is Ownable {
  // Details for a specific batchId
  struct Batch {
    IERC20 token;
    bool approved;
  }

  // Batch Ids
  uint nextId;

  mapping(address => bool) public whitelisted; // whitelisted addresses approved for creating claims
  mapping(uint => Batch) public batchApprovals; // batchId -> Batch details
  mapping(uint => mapping(address => uint)) public amountToClaim; // batchId -> User -> amount
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
   * @notice Allows owner to approve or unapprove batchIds.
   *
   * @param batchIds The list of batchIds to approve or unapprove
   * @param approve Bool on whether the ids are being approved or not
   */
  function approveClaims(uint[] memory batchIds, bool approve) external onlyOwner {
    for (uint i = 0; i < batchIds.length; i++) {
      batchApprovals[batchIds[i]].approved = approve;

      emit ClaimApproved(batchIds[i]);
    }
  }

  //////////////////////////////////
  //   Whitelist-only Functions   //
  //////////////////////////////////

  /**
   * @notice Allows whitelisted addresses to create a batch of new claims.
   *
   * @param tokenAmounts List of token amounts to add for the batch
   * @param users List of user addresses that correspond to the tokenAmounts
   * @param token The reward token
   * @param epochTimestamp The timestamp for the epoch
   * @param tag Data relating to the claim
   */
  function addToClaims(
    uint[] memory tokenAmounts,
    address[] memory users,
    IERC20 token,
    uint epochTimestamp,
    string memory tag
  ) external {
    if (whitelisted[msg.sender] != true) revert MD_NotWhitelisted(msg.sender);
    if (tokenAmounts.length != users.length) revert MD_InvalidArrayLength(tokenAmounts.length, users.length);

    for (uint i = 0; i < users.length; i++) {
      amountToClaim[nextId][users[i]] += tokenAmounts[i];
      emit ClaimAdded(token, users[i], tokenAmounts[i], nextId, epochTimestamp, tag);
    }
    batchApprovals[nextId++].token = token;
  }

  ////////////////////////////
  //   External Functions   //
  ////////////////////////////

  /**
   * @notice Allows user to redeem a list of batchIds.
   * @dev Users can only claim their own rewards.
   * @param claimList List of batchIds to claim
   */
  function claim(uint[] memory claimList) external {
    for (uint i = 0; i < claimList.length; i++) {
      uint batchId = claimList[i];
      if (batchApprovals[batchId].approved != true) revert MD_BatchNotApproved(batchId);

      uint balanceToClaim = amountToClaim[batchId][msg.sender];
      if (balanceToClaim == 0) {
        continue;
      }

      amountToClaim[batchId][msg.sender] = 0;
      totalClaimed[msg.sender][batchApprovals[batchId].token] += balanceToClaim;
      batchApprovals[batchId].token.transfer(msg.sender, balanceToClaim);

      emit Claimed(batchApprovals[batchId].token, msg.sender, batchId, balanceToClaim);
    }
  }

  /**
   * @notice Returns the claimable amount of a a specific token for an address.
   * @param batchIds The list of batchIds to claim
   * @param user The addresses claimable amount
   * @param token The claimable amount for this token
   */
  function getClaimableForUser(uint[] memory batchIds, address user, IERC20 token) external view returns (uint amount) {
    for (uint i = 0; i < batchIds.length; i++) {
      uint balanceToClaim = amountToClaim[batchIds[i]][user];

      if (
        balanceToClaim > 0 && batchApprovals[batchIds[i]].approved == true && batchApprovals[batchIds[i]].token == token
      ) {
        amount += balanceToClaim;
      }
    }
  }

  ////////////
  // Events //
  ////////////

  event WhitelistAddressSet(address user, bool whitelisted);

  event Claimed(IERC20 indexed rewardToken, address indexed claimer, uint indexed batchId, uint amount);

  event ClaimAdded(
    IERC20 rewardToken,
    address indexed claimer,
    uint amount,
    uint indexed batchId,
    uint indexed epochTimestamp,
    string tag
  );

  event ClaimApproved(uint indexed batchId);

  ////////////
  // Errors //
  ////////////

  error MD_NotWhitelisted(address user);
  error MD_InvalidArrayLength(uint tokenLength, uint userLength);
  error MD_BatchNotApproved(uint batchId);
}
