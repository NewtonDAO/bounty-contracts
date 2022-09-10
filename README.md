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
