const { expect, util } = require("chai");
const { ethers } = require("hardhat");

describe("Vault", function () {
    let Vault, vault, MockERC20, USDT, owner, addr1, addr2;

    beforeEach(async function () {
        [owner, addr1, addr2] = await ethers.getSigners();

        MockERC20 = await ethers.getContractFactory("MockERC20");
        USDT = await MockERC20.deploy("mUSDT", "mUSDT");
        await USDT.deployed();

        const UTILS = await ethers.deployContract("Utils");
        
        Vault = await ethers.getContractFactory("Vault", {libraries: {Utils: UTILS.address}});
        vault = await Vault.deploy(
            [USDT.address], // address[] memory _tokens,
            [2000],  // uint256[] memory _newRewardRate, // based 10_000 , 200 = 20%
            [0],  // uint256[] memory _minStakeAmount,
            [ethers.constants.MaxUint256],  // uint256[] memory _maxStakeAmount,
            owner.address,  // address _admin,
            owner.address,  // address _bot,
            owner.address,  // address _ceffu,
            60 * 60 // 1 hour  // uint256 _waitingTime
        );
        await vault.deployed();

        await USDT.mint(owner.address, ethers.utils.parseUnits("10000", 18));
        await USDT.mint(addr1.address, ethers.utils.parseUnits("10000", 18));
        await USDT.mint(addr2.address, ethers.utils.parseUnits("10000", 18));
    });

    it("should deploy Vault and MockERC20 correctly", async function () {
        expect(USDT.address).to.properAddress;
        expect(vault.address).to.properAddress;
    });

    it("should allow staking of tokens", async function () {
        await USDT.connect(addr1).approve(vault.address, ethers.utils.parseUnits("1000", 18));
        await vault.connect(addr1).stake_66380860(USDT.address, ethers.utils.parseUnits("100", 18));

        const stakedAmount = await vault.getStakedAmount(addr1.address, USDT.address);
        expect(stakedAmount).to.equal(ethers.utils.parseUnits("100", 18));
    });

    it("should update reward rate correctly", async function () {
        await vault.setRewardRate(USDT.address, 3000); // update to 30%
        const [newRewardRate, base] = await vault.getCurrentRewardRate(USDT.address);
        expect(newRewardRate).to.equal(3000);
        expect(base).to.equal(10000);
    });

    it("should handle multiple stakes correctly", async function () {
        await USDT.connect(addr1).approve(vault.address, ethers.utils.parseUnits("1000", 18));
        await vault.connect(addr1).stake_66380860(USDT.address, ethers.utils.parseUnits("100", 18));
        await vault.connect(addr1).stake_66380860(USDT.address, ethers.utils.parseUnits("50", 18));

        const totalStaked = await vault.getStakedAmount(addr1.address, USDT.address);
        expect(totalStaked).to.equal(ethers.utils.parseUnits("150", 18));
    });

    it("should allow unstaking of tokens", async function () {
        await USDT.connect(addr1).approve(vault.address, ethers.utils.parseUnits("1000", 18));
        await vault.connect(addr1).stake_66380860(USDT.address, ethers.utils.parseUnits("100", 18));

        const requestId = await vault.lastClaimQueueID();
        
        await vault.connect(addr1).requestClaim_8135334(USDT.address, ethers.utils.parseUnits("50", 18));
        
        console.log("requestId", requestId)

        const RequestClaim = await vault.getClaimQueueInfo(requestId);
        // expect(RequestClaim.amount).to.equal(ethers.utils.parseUnits("50", 18))

        console.log(RequestClaim)
        const remainingStaked = await vault.getStakedAmount(addr1.address, USDT.address);

        expect(

            remainingStaked / 10**18 .toFixed(10)
        ).to.equal(
            ( ethers.utils.parseUnits("100", 18) - RequestClaim.principalAmount) / 10**18 .toFixed(10)
        ); // stake profile should be reduced
    });

    it("should calculate rewards correctly", async function () {
        await USDT.connect(addr1).approve(vault.address, ethers.utils.parseUnits("1000", 18));
        await vault.connect(addr1).stake_66380860(USDT.address, ethers.utils.parseUnits("100", 18));

        // Simulate time passing
        let ONE_YEAR = 31557600
        await ethers.provider.send("evm_increaseTime", [ONE_YEAR / 10 ]); // 1 hour 20 /10 = 2% profit
        await ethers.provider.send("evm_mine");

        const rewards = await vault.getClaimableRewards(addr1.address, USDT.address);

        console.log("rewards", rewards)
        expect(rewards).to.be.equal( ethers.utils.parseUnits("2", 18) );
    });

    it("should handle emergency withdrawal correctly", async function () {
        await USDT.connect(addr1).approve(vault.address, ethers.utils.parseUnits("1000", 18));
        await vault.connect(addr1).stake_66380860(USDT.address, ethers.utils.parseUnits("100", 18));

        await vault.emergencyWithdraw(USDT.address, owner.address);
        const contractBalance = await USDT.balanceOf(vault.address);
        expect(contractBalance).to.equal(0);
    });

    it("should pause and unpause correctly", async function () {
        await vault.pause();
        
        await expect(vault.connect(addr1).stake_66380860(USDT.address, ethers.utils.parseUnits("100", 18)))
            .to.be.revertedWith("EnforcedPause");
        

        await vault.unpause();
        await USDT.connect(addr1).approve(vault.address, ethers.utils.parseUnits("1000", 18));
        await vault.connect(addr1).stake_66380860(USDT.address, ethers.utils.parseUnits("100", 18));

        const stakedAmount = await vault.getStakedAmount(addr1.address, USDT.address);
        expect(stakedAmount).to.equal(ethers.utils.parseUnits("100", 18));
    });
});