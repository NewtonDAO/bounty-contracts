# Newton contract (https://github.com/NewtonDAO/bounty-contracts/blob/main/contracts/bounties.sol)
 
## Remove SafeMath (Done.)

You are using Solidity > 0.8.0 so no need for that. Just remove `.add` `.sub` etc and use `+ - * /` etc.

Overflow protection is built in the compiler so you can save gas by not importing that

## onlyOwner checks for validator (Done.)

```
modifier onlyOwner {
	require(msg.sender == validator);
	_;
}
```

Should be 

```
modifier onlyOwner {
	require(msg.sender == owner);
	_;
}
```

## Unvalidated strings

Be careful with letting people use strings when creating a new bounty as this is not validated on the contract and could cause:

1. Cross-Site Scripting on the website 
2. SQL Injection on the DB 

Ofc this assumes no validation on frontend (If using ReactJS it just html encodes everything so it's not a problem) but using this data in an API and or to query the DB might be risk if not validated. 

You're probably better off using a uint256 value for bounty ID as you can have `115792089237316195423570985008687907853269984665640564039457584007913129639935` bounties in total (yes a lot). This way you don't need an user to input any number, and you just keep a counter that goes up as prople create bounties. I think this would simplify things a lot.

## optimizations/code readability

* (Done.) `numBounties = numBounties++;` can just be `numBounties++;`
* (Done.) No need to add payable to events. 
* No need for `reentrancyGuard` (just remove it):
	-  `contribute` - not calling any external contracts
	-  `acceptAnswer` cannot reenter a `transfer` as there is not enough gas being forwarded plus you are following checks-effect-interaction pattern 
	-  `answerBounty` not calling any external contracts
	-  `refundContribution` checks-effects-interaction is followed 
* (Done.) `acceptAnswer` move `require` at the top of the function 
* (Done.) simplify operations:
	`bounties[_bountyId].balance = bounties[_bountyId].balance + msg.value;`
	Can be `bounties[_bountyId].balance += msg.value;`
* (Done.) add error messages in require statements (helps understanding what's erroring out):
	- `require(x == 5, "Newton: x must be equal to 5");`

## Possible miscalculation (Done.)

`uint protocolFee = uint((10 * _tokenAmount) / 100);`

If token amount is small enough this will result in no fee for the platform. Just be aware or enforce minimum contributions (which in wei will be less than pennies) -> like `require(msg.value >= 100, "Bounty cannot be < 100 wei")`

Tbf it's probably not a problem as it will just result in zero fees, but yea just a suggestion.

## Malicious user could cause no contributions to be awarded

`acceptAnswer` performs a native token transfer to the fulfilment submitter. If someone uses a smart contract to submit an answer, they can add a `revert` statement into the `receive` function and prevent this function from ever succeeding. 

(Done.) One thing to note, is that `transfer` is no longer recommended (https://solidity-by-example.org/sending-ether/), you are better off using `call` or `send`. This way you can check the return value of the call. 

```
  function transferTokens(
    string memory _bountyId,
    address payable _to,
    uint _amount)
    internal
  {
      require(_amount > 0, "Transaction amount inferior or equal to 0"); // Sending 0 tokens should throw
      require(bounties[_bountyId].balance >= _amount, "Not enough money to transact.");
      bounties[_bountyId].balance = bounties[_bountyId].balance - _amount;
      _to.transfer(_amount);
  }
```
 

Malicious contract

```javascript
pragma solidity 0.8.10;

interface INetwon {
    function answerBounty(
    string memory _bountyId,
    string memory _answerHash) external;
}

contract BadReceiver {
    address public owner;
    INetwon public newton;

    constructor(address _newton) {
        owner = msg.sender;
        newton = INetwon(_newton);
    }

    function answer (string memory _bountyId, string memory _answerHash) external {
        require(msg.sender == owner, "Not owner");
        newton.answerBounty(_bountyId, _answerHash);
    }

    function withdraw (address _receiver) external {
        require(msg.sender == owner, "Not owner");
        payable(_receiver).call{value: address(this).balance}("");
    }

    receive() external payable {
        revert("blah");
    }
}
```

Calling accept answer, results in a silent failure (doesn't say revert but funds are not transferred).

```bash
>>> receiver.balance()
0
>>> bounties.balance()
2000000000000000000
>>> bounties.acceptAnswer('bb', 0, 1e18, {'from': validator})
Transaction sent: 0x7d9638821ccba54ce06d1f3743a9211237a22b5d494bb3d5f73e65c4cca1d50e
  Gas price: 0.0 gwei   Gas limit: 12000000   Nonce: 2
  Bounties.acceptAnswer confirmed (blah)   Block: 11   Gas used: 59854 (0.50%)

<Transaction '0x7d9638821ccba54ce06d1f3743a9211237a22b5d494bb3d5f73e65c4cca1d50e'>
>>> receiver.balance()
0
>>> bounties.balance()
2000000000000000000
```

It's not really a big deal as you can just accept another answer, but if you wanted to fix this you either:

1. Prevent smart contracts to submit an answer `require(msg.sender == tx.origin, "No smart contracts allowed")`
2. Check the return value of `transfer`. If false, just wrap matic to WMATIC and transfer like ERC20 as there is no receive function for ERC20.

## `answerBounty` does not check that the bounty has not been refunded

An user would waste gas to submit on chain when he could directly answer without participating in a bounty. Add a check that the question has a bounty.


## (Done.) Not checking that the contract has enough funds to perform a transfer

Function `transferTokens`

```javascript
require(_amount > 0, "Transaction amount inferior or equal to 0"); // Sending 0 tokens should throw
require(bounties[_bountyId].balance >= _amount, "Not enough money to transact.");
bounties[_bountyId].balance = bounties[_bountyId].balance - _amount;
_to.transfer(_amount);
```

You want to add a check:

`require(address(this).balance >= _amount, "Newton: Not enough funds in the contract")`

# Questions
1. Regarding: answer from contract could make reward fail by putting a revert() in the receive() function.
    - If the contract deployers didn't implement their receive() function right it's dumb for them no? (They can't get paid?)
    - Is the downside for us that we lose the gas?
    - Thinking of just implementing a pull pattern instead of push. What do you think?
2. Regarding: user wasting money by answering a question that doesn't have a bountyt
    - I want all the questions and answers to be on chain (at least in the form a their hash). It excites me to think we could have a completly public, untemperable record of knowledge. 
    - We'll eat out the transactions and give users links to their transactions.
