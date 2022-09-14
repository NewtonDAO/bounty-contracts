const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Bounty functions:", function () {
	let owner;
	let contributor;
	let answerer;
	let bounties;

	beforeEach(async function () {
		// Get the ContractFactory and Signers here.
		const Bounties = await ethers.getContractFactory("Bounties");
		[owner, contributor, answerer, random] = await ethers.getSigners();
		bounties = await Bounties.deploy();
		//console.log("Fresh Deploy of Contract to:", bounties.address);
		//console.log("Contributor Address: ", contributor.address);
	});

	/* To run this test, hardcode the timeout in the contract
	 * to zero blocks and re-compile
	 */
	/* 
	describe("#refundContribution", function() {
		it("Should create bounty, then withdraw", async function() {
			const _amount = ethers.utils.parseEther((1 / 10000).toString());
			await bounties
				.connect(contributor)
				.issueBountyAndContribute(contributor.address, "Give me my Money Back!", _amount, {
					value: _amount,
				});
			expect(await bounties.numBounties()).to.equal(1);

			await bounties
				.connect(contributor)
				.refundContribution(contributor.address, "0",0);
			expect(await bounties.numBounties()).to.equal(1);


		});
	});

        */

	describe("Function: issueAndContribute", function () {
		it("Should create bounty", async function () {
			const _amount = ethers.utils.parseEther((1 / 10000).toString());
			await bounties
				.connect(contributor)
				.issueBountyAndContribute("bountyId", "questionHash", {
					value: _amount,
				});
			expect(await bounties.numBounties()).to.equal(1);
		});
	});

	describe("Function: contribute", function () {
		beforeEach(async function () {
			expect(await bounties.numBounties()).to.equal(0);
			expect(await bounties.getTotalSupply()).to.equal(0);
			const _amount = ethers.utils.parseEther("1");
			await bounties
				.connect(contributor)
				.issueBountyAndContribute("bountyId", "questionHash", {
					value: _amount,
				});
			totalSupply1 = await bounties.getTotalSupply();
			await bounties
				.connect(random)
				.issueBountyAndContribute("bountyId2", "questionHash", {
					value: _amount,
				});
			expect(await bounties.numBounties()).to.equal(2);
			totalSupply2 = await bounties.getTotalSupply();
			increaseAmt = totalSupply2 - totalSupply1;
			expect(increaseAmt - _amount).to.equal(0);
		});

		it("Should contribute to bounty", async function () {
			const _amount = ethers.utils.parseEther("1");
			await bounties.connect(contributor).contribute("bountyId", {
				value: _amount,
			});
			const bounty = await bounties.getBounty("bountyId");

			expect(bounty.contributions).to.have.lengthOf(2);
			expect(bounty.contributions[1].amount).to.equal(_amount);
		});
	});

	describe("Function: fulfill", function () {
		beforeEach(async function () {
			const _amount = ethers.utils.parseEther("1");
			await bounties
				.connect(contributor)
				.issueBountyAndContribute("bountyId", "questionHash", {
					value: _amount,
				});
		});

		const test = async () => {
			await bounties.connect(answerer).answerBounty("bountyId", "answerHash");
			return await bounties.getBounty("bountyId");
		};
		it("Should create a bounty", async function () {
			const bounty = await test();
			expect(bounty.fulfillments).to.have.lengthOf(1);
		});

		it("Fulfillment should have a timestamp.", async function () {
			const bounty = await test();
			expect(bounty.fulfillments[0].timestamp.toNumber()).to.be.a("number");
		});
	});

	describe("Function: transfer", function () {
		const _amount = ethers.utils.parseEther("100");
		beforeEach(async function () {
			await bounties
				.connect(contributor)
				.issueBountyAndContribute("bountyId", "questionHash", {
					value: _amount,
				});
			await bounties.connect(answerer).answerBounty("bountyId", "answerHash");
		});
		it("Balance should be 100 eth", async function () {
			const bounty = await bounties.getBounty("bountyId");
			expect(bounty.balance).to.equal(_amount);
		});
		it("Should have empty bounty balance", async function () {
			await bounties.connect(owner).acceptAnswer("bountyId", 0, _amount);
			const bounty = await bounties.getBounty("bountyId");
			expect(bounty.balance).to.equal(ethers.utils.parseEther("0"));
		});
		it("Should have different owner balance", async function () {
			const prevBalance = await ethers.provider.getBalance(owner.address);
			await bounties.connect(owner).acceptAnswer("bountyId", 0, _amount);
			const nextBalance = await ethers.provider.getBalance(owner.address);
			expect(nextBalance == prevBalance).to.be.false;
		});
		it("Should have different submitter balance", async function () {
			const prevBalance = await ethers.provider.getBalance(answerer.address);
			await bounties.connect(owner).acceptAnswer("bountyId", 0, _amount);
			const nextBalance = await ethers.provider.getBalance(answerer.address);
			expect(nextBalance == prevBalance).to.be.false;
		});
	});

	describe("Function: withdraw", function () {
		const _amount = ethers.utils.parseEther("100");
		beforeEach(async function () {
			await bounties
				.connect(contributor)
				.issueBountyAndContribute("bountyId", "questionHash", {
					value: _amount,
				});
		});
		it("Should withdraw to owner.", async function () {
			const prevBalance = await ethers.provider.getBalance(owner.address);
			expect(await bounties.connect(owner).getTotalSupply()).to.equal(
				ethers.utils.parseEther("100")
			);
			await bounties.connect(owner).withdraw();
			expect(await bounties.connect(owner).getTotalSupply()).to.equal(
				ethers.utils.parseEther("0")
			);
			const nextBalance = await ethers.provider.getBalance(owner.address);
			expect(prevBalance == nextBalance).to.be.false;
		});
	});
});
