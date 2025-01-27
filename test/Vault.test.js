const { expect } = require("chai");
const hre = require("hardhat");
const keccak256 = require('keccak256')



const { joinSignature } = require('ethers/utils/bytes')//keccak256,


// const { time } = require("@nomicfoundation/hardhat-toolbox/network-helpers");

describe("Lock", function () {

  beforeEach(async () => {
    

    accounts = await ethers.getSigners();

    users = config.networks.hardhat.accounts;
    const index = 0; // second wallet, increment for next wallets
    wallet = ethers.Wallet.fromMnemonic(users.mnemonic, users.path + `/${index}`);

    console.log(wallet.getAddress()) 

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
  it("Should set the right unlockTime", async function () {
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

    const VAULT = await hre.ethers.deployContract("YesuVault");
    console.log(VAULT.address)

    await VAULT.setCompleted(1)

    const DOMAIN_SEPARATOR = await VAULT.DOMAIN_SEPARATOR();
    console.log("DOMAIN", DOMAIN_SEPARATOR)
    const PERMIT_TYPEHASH =await VAULT.PERMIT_TYPEHASH();// keccak256("Claim(uint256 investId,uint256 amount,address to,uint256 nonce,uint256 deadline)");
    console.log("PERMIT_TYPEHASH", PERMIT_TYPEHASH.toString('hex'))

    const encodeData = ethers.utils.solidityPack(
      ['bytes1', 'bytes1', 'bytes32', 'bytes32'],
      [
      '0x19',
      '0x01',
      DOMAIN_SEPARATOR,
      keccak256(
        web3.eth.abi.encodeParameters(
          ['bytes32','uint256', 'uint256', 'address', 'uint256'],
        [
          // [PERMIT_TYPEHASH, approve.owner, approve.spender, approve.value, deadline]
          PERMIT_TYPEHASH, 1, 2, accounts[0].address, 3
        ]
        )
      )
    ]);
    console.log("encodeData.js:", encodeData);
    const digest = keccak256(
      encodeData
    )
    key = wallet._signingKey().signDigest("0x"+digest.toString('hex'))
    let sign = joinSignature(key);
    console.log("sign", sign)


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