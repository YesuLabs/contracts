const { expect } = require("chai");
const hre = require("hardhat");
const keccak256 = require('keccak256')



const { joinSignature } = require('ethers/utils/bytes')//keccak256,


// const { time } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("Vault test", function () {

  beforeEach(async () => {
    

    accounts = await ethers.getSigners();

    users = config.networks.hardhat.accounts;
    const index = 0; // second wallet, increment for next wallets
    wallet = await ethers.Wallet.fromMnemonic(users.mnemonic, users.path + `/${index}`);


    console.log(await wallet.getAddress()) 

      // const ArkSpace = await ethers.getContractFactory('ArkSpace');
      // const MockERC20 = await ethers.getContractFactory('MockERC20');

      // USDT = await MockERC20.deploy("mUSDT", "mUSDT");
      // ARK = await MockERC20.deploy("ARK", "ARK");

      // SPACE = await ArkSpace.deploy();

      // await SPACE.initialize(
      //   USDT.address, // address _raiseToken,
      //   ARK.address, // address _offeringToken,
      //   accounts[0].address  // address _agentManager
      // );

      // console.log("USDT:", USDT.address);
      // console.log("ARK:", ARK.address);
      // console.log("SPACE:", SPACE.address);

    });
  it("Verify test", async function () {
    const lockedAmount = 1_000_000_000;
    const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
    // const unlockTime = (await time.latest()) + ONE_YEAR_IN_SECS;

    // deploy a lock contract where funds can be withdrawn
    // // one year in the future
    // const lock = await hre.ethers.deployContract("Lock", [unlockTime], {
    //   value: lockedAmount,
    // });

    // // assert that the value is correct
    // expect(await lock.unlockTime()).to.equal(unlockTime);

    const VAULT = await hre.ethers.deployContract("YesuVault", [accounts[0].address, accounts[0].address]);
    console.log(VAULT.address)


    const gm = '0x521dE0579d9b20bdbAc4313E2F81181179521b1e';
    const pk   = '0x196ba6a4a0e40c91f012d2cdd68d7810255b70d349aa3a91a0577c6bd56d959e';
    
    const data =   web3.eth.abi.encodeParameters(
      ['uint256', 'uint256', 'address', 'uint256'],
    [
      // [PERMIT_TYPEHASH, approve.owner, approve.spender, approve.value, deadline]
       1, 2, accounts[0].address, 3
    ]
    );
    const shaData = web3.utils.sha3(data);
    const sign2 = web3.eth.accounts.sign(shaData, pk);
    
    tx = await VAULT.setManager(gm);
    console.log("tx:", tx)

    console.log(sign2)

    await VAULT.checkSign(1, 2, accounts[0].address, 3, sign2.signature);
  });
});