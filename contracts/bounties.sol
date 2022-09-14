// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "hardhat/console.sol";

contract Bounties is ReentrancyGuard {
  using SafeMath for uint256;

  // STRUCTS
  struct Bounty {
    address payable issuer; 
    uint deadline; 
    uint balance; 
    bool hasBeenAnswered;
    string questionHash; 
    Fulfillment[] fulfillments; 
    Contribution[] contributions; 
  }

  struct Fulfillment {
    string answerId; // Answer DocId
    address payable submitter;
    uint timestamp;
  }

  struct Contribution {
    address payable contributor; 
    uint amount;
    bool refunded;
  }

  // STORAGE
  uint public numBounties; // An integer storing the total number of bounties in the contract
  mapping(string => Bounty) public bounties; // A mapping of bountyIDs to bounties

  address public owner; 
  bool public callStarted; // Ensures mutex for the entire contract

  // MODIFIERS

  modifier validateContributionArrayIndex(
    string memory _bountyId,
    uint _index)
  {
    require(_index < bounties[_bountyId].contributions.length);
    _;
  }

  modifier validateFulfillmentArrayIndex(
    string memory _bountyId,
    uint _index)
  {
    require(_index < bounties[_bountyId].fulfillments.length);
    _;
  }

  modifier onlyOwner {
    require(msg.sender == owner);
    _;
  }

  modifier onlyContributor(
    string memory _bountyId,
    uint _contributionId
  )
  {
    require(msg.sender == bounties[_bountyId].contributions[_contributionId].contributor);
    _;
  }

  modifier hasNoAnswers(
    string memory _bountyId)
  {
    require(!bounties[_bountyId].hasBeenAnswered);
    _;
  }
  
  modifier isOverDeadline(
    string memory _bountyId)
  {
    require(block.timestamp > bounties[_bountyId].deadline); 
    _;
  }

  modifier hasNotRefunded(
    string memory _bountyId,
    uint _contributionId)
  {
    require(!bounties[_bountyId].contributions[_contributionId].refunded);
    _;
  }

  modifier bountyIdDoesNotExist(
    string memory _bountyId)
  {
    require(bounties[_bountyId].deadline == 0);
    _;
  }

  constructor() {
    owner = msg.sender;
  }

  

  // FUNCTIONS
  /*
    @dev issueBountyAndContribute(): creates a new bounty and fund it
    @param _questionHash documentId in the projet database. TODO: make hash of all question data
  */
  function issueBountyAndContribute(
      string memory _bountyId,
      string memory _questionHash
    )
    public
    payable
    bountyIdDoesNotExist(_bountyId)
  {
    issueBounty(_bountyId, _questionHash);
    contribute(_bountyId);
  }

  /*
    @dev issueBounty(): creates a new bounty, called by issueBountyAndContribute
    @param _questionHash documentId in the projet database. TODO: make hash of all question data
  */
  function issueBounty(
    string memory _bountyId,
    string memory _questionHash)
    internal
  {

    Bounty storage newBounty = bounties[_bountyId];
    newBounty.issuer = payable(msg.sender);
    newBounty.deadline = block.timestamp + 86400 * 5; // 5 days
    newBounty.questionHash = _questionHash;

    // Increments the new total number of bounties
    numBounties = numBounties.add(1);

    emit BountyIssued(_bountyId, payable(msg.sender), _questionHash, newBounty.deadline);
  }


  /* 
    @dev contribute(): Contribute tokens to a given bounty. 
    
    @param _bountyId the index of the bounty
  */
  function contribute(
      string memory _bountyId
    )
    public
    payable
    nonReentrant
  {

    // Contributions of 0 tokens or token ID 0 should fail
    require(msg.value > 0, 'Amount inferior to 0.'); 

    // Adds the contribution to the bounty
    bounties[_bountyId].contributions.push(Contribution(payable(msg.sender), msg.value, false)); 

    // Increments the balance of the bounty
    bounties[_bountyId].balance = bounties[_bountyId].balance.add(msg.value); 

    // The contribution's index will always equal the number of existing contributions
    uint contributionId = bounties[_bountyId].contributions.length - 1; 

    emit ContributionAdded(_bountyId, contributionId, payable(msg.sender), msg.value);
  }

  /*
    @dev refundContribution(): Allow user to refund a contribution if the deadline is passed and there are no answers
    @param _bountyId the index of the bounty
    @param _contributionId the index of the contribution being refunded
  */
  function refundContribution(
    string memory _bountyId,
    uint _contributionId)
    public
    validateContributionArrayIndex(_bountyId, _contributionId)
    onlyContributor(_bountyId, _contributionId)
    hasNoAnswers(_bountyId)
    hasNotRefunded(_bountyId, _contributionId)    
    isOverDeadline(_bountyId)
    nonReentrant
  {

    Contribution storage contribution = bounties[_bountyId].contributions[_contributionId];

    contribution.refunded = true;
    transferTokens(_bountyId, contribution.contributor, contribution.amount);

    emit ContributionRefunded(_bountyId, _contributionId);
  }

  /* 
    @dev answerBounty(): Allows users to fulfill the bounty to get paid out
    @param _bountyId the index of the bounty
    @param _answerId the documentId of the answer in Narcissa. TODO: change to hash of answer
  */
  function answerBounty(
    string memory _bountyId,
    string memory _answerHash)
    public
    nonReentrant
  {
    bounties[_bountyId].hasBeenAnswered = true; // Disables refunds
    bounties[_bountyId].fulfillments.push(Fulfillment(_answerHash, payable(msg.sender), block.timestamp));
    uint answerIndex = bounties[_bountyId].fulfillments.length - 1;

    emit BountyFulfilled(_bountyId, payable(msg.sender), _answerHash, answerIndex);
  }

  /*
    @dev acceptAnswer(): Allows any of the approvers to accept a given submission
    @param _bountyId the index of the bounty
    @param _answerId the index of the fulfillment to be accepted
    @param _tokenAmount how much tokens to transfer to the fulfiller 
  */
  function acceptAnswer(
    string memory _bountyId,
    uint _answerId, // Index in fullfilments
    uint _tokenAmount)
    public
    validateFulfillmentArrayIndex(_bountyId, _answerId)
    onlyOwner
    nonReentrant
  {

    Fulfillment storage fulfillment = bounties[_bountyId].fulfillments[_answerId];
    require(_tokenAmount > 0, "Token amount is inferior to 0.");

    uint protocolFee = uint((10 * _tokenAmount) / 100);
    transferTokens(_bountyId, payable(owner), protocolFee);
    transferTokens(_bountyId, fulfillment.submitter, _tokenAmount - protocolFee);
    emit AnswerAccepted(_bountyId, _answerId, _tokenAmount);
  }

  /* 
    @dev getBounty(): Returns the details of the bounty
    
    @param _bountyId the index of the bounty
    @return Returns a tuple for the bounty
  */
  function getBounty(string memory _bountyId) external view returns (Bounty memory) 
  {
    return bounties[_bountyId];
  }

  /* 
    @dev transferTokens(): Returns the details of the bounty
    
    @param _bountyId the index of the bounty
    @param _to the address to transfer the tokens to
    @param _amount the amount of tokens to transfer
  */
  function transferTokens(
    string memory _bountyId,
    address payable _to,
    uint _amount)
    internal
  {
      require(_amount > 0, "Transaction amount inferior or equal to 0"); // Sending 0 tokens should throw
      require(bounties[_bountyId].balance >= _amount, "Not enough money to transact.");
      bounties[_bountyId].balance = bounties[_bountyId].balance.sub(_amount);
      _to.transfer(_amount);
  }

  /* 
    @dev withdraw(): In case s.o. hacked the contract, this function will be called to safekeep the tokens
    
    @param _bountyId the index of the bounty
    @param _to the address to transfer the tokens to
    @param _amount the amount of tokens to transfer
  */
  function withdraw()
    external
    onlyOwner
  {
    uint totalSupply = address(this).balance;
    payable(owner).transfer(totalSupply);
  }

  function getTotalSupply() external view returns (uint)
  {
    return address(this).balance;
  }

  // EVENTS
  event BountyIssued(string _bountyId, address payable _issuer, string _questionHash, uint _deadline);
  event ContributionAdded(string _bountyId, uint _contributionId, address payable _contributor, uint _amount);
  event ContributionRefunded(string _bountyId, uint _contributionId);
  event BountyFulfilled(string _bountyId, address payable _sender, string _answerHash, uint numFulfillments);
  event AnswerAccepted(string _bountyId, uint  _fulfillmentId, uint _tokenAmount);
}
