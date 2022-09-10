// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "hardhat/console.sol";

contract Bounties {
  using SafeMath for uint256;

  // STRUCTS
  struct Bounty {
    address payable issuer; 
    uint deadline; 
    uint balance; 
    bool hasBeenAnswered;
    string questionId; 
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
  mapping(uint => Bounty) public bounties; // A mapping of bountyIDs to bounties

  address public owner; 
  bool public callStarted; // Ensures mutex for the entire contract

  // MODIFIERS
  modifier callNotStarted(){
    require(!callStarted);
    callStarted = true;
    _;
    callStarted = false;
  }

  modifier validateBountyArrayIndex(
    uint _index)
  {
    require(_index < numBounties, "BountyArrayIndex out of bounds");
    _;
  }

  modifier validateContributionArrayIndex(
    uint _bountyId,
    uint _index)
  {
    require(_index < bounties[_bountyId].contributions.length);
    _;
  }

  modifier validateFulfillmentArrayIndex(
    uint _bountyId,
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
    uint _bountyId,
    uint _contributionId
  )
  {
    require(msg.sender == bounties[_bountyId].contributions[_contributionId].contributor);
    _;
  }

  modifier hasNoAnswers(
    uint _bountyId)
  {
    require(!bounties[_bountyId].hasBeenAnswered);
    _;
  }
  
  modifier isOverDeadline(
    uint _bountyId)
  {
    require(block.timestamp > bounties[_bountyId].deadline); 
    _;
  }

  modifier hasNotRefunded(
    uint _bountyId,
    uint _contributionId)
  {
    require(!bounties[_bountyId].contributions[_contributionId].refunded);
    _;
  }

  constructor() {
    owner = msg.sender;
  }

  

  // FUNCTIONS
  /*
    @dev issueBountyAndContribute(): creates a new bounty and fund it
    @param _questionId documentId in the projet database. TODO: make hash of all question data
  */
  function issueBountyAndContribute(
      string memory _questionId
    )
    public
    payable     
  {

    /* TODO: Should check that _questionId does not already exist? */

    uint bountyId = issueBounty(_questionId);
    contribute(bountyId);
  }

  /*
    @dev issueBounty(): creates a new bounty, called by issueBountyAndContribute
    @param _questionId documentId in the projet database. TODO: make hash of all question data
  */
  function issueBounty(
    string memory _questionId)
    internal 
    returns (uint)
  {
    // The next bounty's index is the number of existing bounties
    uint bountyId = numBounties;
    
    Bounty storage newBounty = bounties[bountyId];
    newBounty.issuer = payable(msg.sender);
    newBounty.deadline = block.timestamp + 86400 * 5; // 5 days
    newBounty.questionId = _questionId;

    // Increments the new total number of bounties
    numBounties = numBounties.add(1);

    emit BountyIssued(bountyId, payable(msg.sender), _questionId, newBounty.deadline);
    return bountyId;
  }


  /* 
    @dev contribute(): Contribute tokens to a given bounty. 
    
    @param _bountyId the index of the bounty
  */
  function contribute(
      uint _bountyId
    )
    public
    payable
    validateBountyArrayIndex(_bountyId)
    callNotStarted
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
    @dev refundContribution(): Allow user to refund a contribution if 
                               the deadline is passed and there are no answers
    
    @param _bountyId the index of the bounty
    @param _contributionId the index of the contribution being refunded
  */
  function refundContribution(
    uint _bountyId,
    uint _contributionId)
    public
    validateBountyArrayIndex(_bountyId)
    validateContributionArrayIndex(_bountyId, _contributionId)
    onlyContributor(_bountyId, _contributionId)
    hasNoAnswers(_bountyId)
    hasNotRefunded(_bountyId, _contributionId)    
    isOverDeadline(_bountyId)
    callNotStarted
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
    uint _bountyId,
    string memory _answerId)
    public
    validateBountyArrayIndex(_bountyId)
  {
    bounties[_bountyId].hasBeenAnswered = true; // Disables refunds
    bounties[_bountyId].fulfillments.push(Fulfillment(_answerId, payable(msg.sender), block.timestamp));
    uint answerIndex = bounties[_bountyId].fulfillments.length - 1;

    emit BountyFulfilled(_bountyId, payable(msg.sender), _answerId, answerIndex);
  }

  /*
    @dev acceptAnswer(): Allows any of the approvers to accept a given submission
    @param _bountyId the index of the bounty
    @param _answerId the index of the fulfillment to be accepted
    @param _tokenAmount how much tokens to transfer to the fulfiller 
  */
  function acceptAnswer(
    uint _bountyId,
    uint _answerId, // Index in fullfilments
    uint _tokenAmount)
    public
    validateBountyArrayIndex(_bountyId)
    validateFulfillmentArrayIndex(_bountyId, _answerId)
    onlyOwner
    callNotStarted
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
  function getBounty(uint _bountyId) external view returns (Bounty memory) 
  {
    return bounties[_bountyId];
  }

  /* 
    @dev transferTokens(): Returns the details of the bounty
    
    @param _bountyId the index of the bounty
    @param _to the address to transfer the tokens to
    @param _amount the amount of tokens to transfer
  */
  function transferTokens(uint _bountyId, address payable _to, uint _amount)
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
  event BountyIssued(uint _bountyId, address payable _issuer, string _questionId, uint _deadline);
  event ContributionAdded(uint _bountyId, uint _contributionId, address payable _contributor, uint _amount);
  event ContributionRefunded(uint _bountyId, uint _contributionId);
  event BountyFulfilled(uint _bountyId, address payable _sender, string _answerId, uint numFulfillments);
  event AnswerAccepted(uint _bountyId, uint  _fulfillmentId, uint _tokenAmount);
}
