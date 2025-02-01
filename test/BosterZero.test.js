const { expect } = require("chai");
const hre = require("hardhat");
const keccak256 = require('keccak256')



const { joinSignature } = require('ethers/utils/bytes');//keccak256,
const { time, balance } = require("@openzeppelin/test-helpers");
// const { ethers } = require("ethers");


// const { time } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("Booster test", function () {

  beforeEach(async () => {
    

    accounts = await ethers.getSigners();

    [owner, addr1, addr2] = accounts;

    users = config.networks.hardhat.accounts;
    const index = 0; // second wallet, increment for next wallets
    wallet = await ethers.Wallet.fromMnemonic(users.mnemonic, users.path + `/${index}`);

    console.log(await wallet.getAddress()) 

    const MockERC20 = await ethers.getContractFactory('MockERC20');
    USDT = await MockERC20.deploy("mUSDT", "mUSDT");
    console.log("USDT:", USDT.address);


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

    StrategyZero = await ethers.getContractFactory("StrategyZero");

    STG = await StrategyZero.deploy();

    const YesuBooster = await ethers.getContractFactory('YesuBooster');
    BOOSTER = await YesuBooster.deploy(vault.address, STG.address);
    
    console.log("BOOSTER:", BOOSTER.address);



  });
  it("Stake multiple test", async function () {

    await USDT.approve(BOOSTER.address, ethers.utils.parseUnits("2000", 18));

    await BOOSTER.stake(USDT.address , ethers.utils.parseUnits("1000", 18));
    await BOOSTER.stake(USDT.address , ethers.utils.parseUnits("500", 18));

    const balance = await BOOSTER.userInfo(owner.address, USDT.address);
    expect(balance.amount).to.equal(ethers.utils.parseUnits("1500", 18));

  });

  it("should allow unstaking of tokens", async function () {

          await USDT.connect(addr1).approve(BOOSTER.address, ethers.utils.parseUnits("1000", 18));
          await BOOSTER.connect(addr1).stake(USDT.address, ethers.utils.parseUnits("100", 18));
  
          const requestId = 1;
          
          await BOOSTER.connect(addr1).requestClaim(USDT.address, ethers.utils.parseUnits("50", 18));
          
          console.log("requestId", requestId)
  
          const RequestClaim = await BOOSTER.getClaimQueueInfo(requestId);
  
          console.log(RequestClaim)
          const remainingStaked = await BOOSTER.getStakedAmount(addr1.address, USDT.address);
  
          expect(
  
              remainingStaked / 10**18 .toFixed(10)
          ).to.equal(
              ( ethers.utils.parseUnits("100", 18) - RequestClaim.principalAmount) / 10**18 .toFixed(10)
          ); // stake profile should be reduced

          time.increase(60 * 60 * 24 * 30); // 30 days

          const balancePre =  await USDT.balanceOf(addr1.address);
          await BOOSTER.connect(addr1).claim(requestId);
          const newBalance = await USDT.balanceOf(addr1.address);

          const balanceDiff = newBalance.sub(balancePre);

          expect(balanceDiff).to.equal(RequestClaim.totalAmount);

    });

    it("should calculate rewards correctly", async function () {
            await USDT.connect(addr1).approve(BOOSTER.address, ethers.utils.parseUnits("1000", 18));
            await BOOSTER.connect(addr1).stake(USDT.address, ethers.utils.parseUnits("100", 18));
    
            // Simulate time passing
            let ONE_YEAR = 31557600
            await ethers.provider.send("evm_increaseTime", [ONE_YEAR / 10 ]); // 1 hour 20 /10 = 2% profit
            await ethers.provider.send("evm_mine");
    
            const rewards = await BOOSTER.getClaimableRewards(addr1.address, USDT.address);
    
            console.log("rewards", rewards)
            expect(rewards).to.be.equal( ethers.utils.parseUnits("2", 18) );
      });
  
});