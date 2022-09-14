# Newton Hardhat Repository

Organization:

```
├── artifacts
│   └── compiled solidity contracts
├── contracts
│   └── solidity contract source
├── scripts/
│   └── useful scripts (deployment etc...)
└── test/
    └── unit & integration tests for smart contracts
```

## Some deets (2022-09-07)

- Before: `nvm intall 16.17.0` (To make sure you are using a recent verion of node.)
- Setup: `npm install`
- Update hardhat.config.js with your key values.
- Compile: `npx hardhat compile`
- Test: `npx hardhat test`
- Deploy: `npx hardhat run scripts/deploy.js --network <network-name>`

## Some documentation

- `issueBountyAndContribute()`: Calls issueBounty() and contribute().
- `issueBounty()`: Creates a bounty and stores the hash of its content questionHash.
- `contribute()`: Contribute the transaction tokens to a specific bounty.
- `refundContribution()`: Refund user contribution. Only works under certain conditions.
- `answerBounty()`: Submit and answer to a bounty and store its hash.
- `acceptAnswer()`: Lets the validator accept an answer and call the transfer() function.
- `getBounty`: Returns the information on a bounty.
- `getTotalSupply()`: Returns the total amount of bounties.
- `transferTokens()`: Internal function to allocate the bounty funds to a user.
- `setValidator()`: Allow the contract owner to set a validator.
- `withdraw()`: Allow the owner (Newton) to withdraw the funds in case of a breach.
