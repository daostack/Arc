const helpers = require('./helpers');
var FixedReputationAllocation = artifacts.require("./FixedReputationAllocation.sol");

class FixedReputationAllocationParams {
  constructor() {
  }
}

const setup = async function (accounts,
                              _repAllocation = 300,
                              _initialize = true,
                              _redeemEnableTime = 3000) {

   var testSetup = new helpers.TestSetup();
   testSetup.proxyAdmin = accounts[5];
   var registration = await helpers.registerImplementation();
   testSetup.org = await helpers.setupOrganizationWithArraysDAOFactory(
     testSetup.proxyAdmin,
     accounts,
     registration,
     [accounts[0]],
     [0],
     [0]
  );

  testSetup.fixedReputationAllocationParams = new FixedReputationAllocationParams();
  var block = await web3.eth.getBlock("latest");
  testSetup.redeemEnableTime = block.timestamp + _redeemEnableTime;

  if (_initialize === true) {
   testSetup.fixedReputationAllocationParams.initdata = await new web3.eth.Contract(registration.fixedReputationAllocation.abi)
   .methods
   .initialize(testSetup.org.avatar.address,
              _repAllocation,
              testSetup.redeemEnableTime,
              accounts[0])
               .encodeABI();
    } else {
      testSetup.fixedReputationAllocationParams.initdata = Buffer.from('');
    }

   var permissions = "0x00000000";

   var tx = await registration.daoFactory.setSchemes(
    testSetup.org.avatar.address,
    [web3.utils.fromAscii("FixedReputationAllocation")],
    testSetup.fixedReputationAllocationParams.initdata,
    [helpers.getBytesLength(testSetup.fixedReputationAllocationParams.initdata)],
    [permissions],
    "metaData",{from:testSetup.proxyAdmin});
   testSetup.fixedReputationAllocation = await FixedReputationAllocation.at(tx.logs[1].args._scheme);
   return testSetup;
};

contract('FixedReputationAllocation', accounts => {
    it("initialize", async () => {
      let testSetup = await setup(accounts);
      assert.equal(await testSetup.fixedReputationAllocation.reputationReward(),300);
      assert.equal(await testSetup.fixedReputationAllocation.isEnable(),false);
      assert.equal(await testSetup.fixedReputationAllocation.redeemEnableTime(),testSetup.redeemEnableTime);
    });

    it("add beneficiary", async () => {
       let testSetup = await setup(accounts);
       let tx = await testSetup.fixedReputationAllocation.addBeneficiary(accounts[0]);
       assert.equal(tx.logs.length,1);
       assert.equal(tx.logs[0].event,"BeneficiaryAddressAdded");
       assert.equal(tx.logs[0].args._beneficiary,accounts[0]);
    });

    it("add beneficiary check only owner", async () => {
       let testSetup = await setup(accounts);
       try {
         await testSetup.fixedReputationAllocation.addBeneficiary(accounts[0],{from: accounts[1]});
         assert(false, "addBeneficiary is only owner");
       } catch(error) {
         helpers.assertVMException(error);
       }
    });

    it("add beneficiaries", async () => {
      let testSetup = await setup(accounts);
      let tx = await testSetup.fixedReputationAllocation.addBeneficiaries(accounts);
      assert.equal(tx.logs.length,accounts.length);
    });

    it("redeem", async () => {
      let testSetup = await setup(accounts);
      let tx = await testSetup.fixedReputationAllocation.addBeneficiaries(accounts);
      assert.equal(await testSetup.fixedReputationAllocation.numberOfBeneficiaries(),accounts.length);
      assert.equal(await testSetup.fixedReputationAllocation.beneficiaryReward(),0);
      await testSetup.fixedReputationAllocation.enable();
      assert.equal(await testSetup.fixedReputationAllocation.beneficiaryReward(),300/accounts.length);
      var beneficiaryReward;
      var reputation;
      await helpers.increaseTime(3001);
      for (var i = 0 ;i< accounts.length ;i++) {
          tx = await testSetup.fixedReputationAllocation.redeem(accounts[i]);
          assert.equal(tx.logs.length,1);
          assert.equal(tx.logs[0].event,"Redeem");
          beneficiaryReward = await testSetup.fixedReputationAllocation.beneficiaryReward();
          assert.equal(tx.logs[0].args._amount,beneficiaryReward.toNumber());
          reputation = await testSetup.org.reputation.balanceOf(accounts[i]);
          assert.equal(reputation.toNumber(),tx.logs[0].args._amount);
      }

    });

    it("cannot redeem twice", async () => {
      let testSetup = await setup(accounts);
      let tx = await testSetup.fixedReputationAllocation.addBeneficiaries(accounts);
      assert.equal(await testSetup.fixedReputationAllocation.numberOfBeneficiaries(),accounts.length);
      assert.equal(await testSetup.fixedReputationAllocation.beneficiaryReward(),0);
      await testSetup.fixedReputationAllocation.enable();
      assert.equal(await testSetup.fixedReputationAllocation.beneficiaryReward(),300/accounts.length);
      var beneficiaryReward;
      var reputation;
      await helpers.increaseTime(3001);
      for (var i = 0 ;i< accounts.length ;i++) {
          tx = await testSetup.fixedReputationAllocation.redeem(accounts[i]);
          assert.equal(tx.logs.length,1);
          assert.equal(tx.logs[0].event,"Redeem");
          beneficiaryReward = await testSetup.fixedReputationAllocation.beneficiaryReward();
          assert.equal(tx.logs[0].args._amount,beneficiaryReward.toNumber());
          reputation = await testSetup.org.reputation.balanceOf(accounts[i]);
          assert.equal(reputation.toNumber(),tx.logs[0].args._amount);
      }

      try {
        await testSetup.fixedReputationAllocation.redeem(accounts[0]);
        assert(false, "cannot redeem  twice");
      } catch(error) {
        helpers.assertVMException(error);
      }
    });

    it("cannot addBeneficiaries if not initialize", async () => {
      let testSetup = await setup(accounts,300,false);
      try {
        await testSetup.fixedReputationAllocation.addBeneficiaries(accounts);
        assert(false, "cannot addBeneficiaries if not initialize");
      } catch(error) {
        helpers.assertVMException(error);
      }
    });

    it("cannot redeem before redeemEnableTime", async () => {
      let testSetup = await setup(accounts);
      await testSetup.fixedReputationAllocation.addBeneficiaries(accounts);
      assert.equal(await testSetup.fixedReputationAllocation.numberOfBeneficiaries(),accounts.length);
      assert.equal(await testSetup.fixedReputationAllocation.beneficiaryReward(),0);
      await testSetup.fixedReputationAllocation.enable();
      try {
        await testSetup.fixedReputationAllocation.redeem(accounts[0]);
        assert(false, "cannot redeem if not initialize");
      } catch(error) {
        helpers.assertVMException(error);
      }
      await helpers.increaseTime(3001);
      await testSetup.fixedReputationAllocation.redeem(accounts[0]);


    });

    it("redeem without enable should revert", async () => {
      let testSetup = await setup(accounts);
      await testSetup.fixedReputationAllocation.addBeneficiaries(accounts);
      try {
        await testSetup.fixedReputationAllocation.redeem(accounts[0]);
        assert(false, "redeem without enable should revert");
      } catch(error) {
        helpers.assertVMException(error);
      }
    });

    it("redeem from none white listed beneficiary should revert", async () => {
      let testSetup = await setup(accounts);
      await testSetup.fixedReputationAllocation.addBeneficiary(accounts[0]);
      await testSetup.fixedReputationAllocation.enable();
      try {
        await testSetup.fixedReputationAllocation.redeem(accounts[1]);
        assert(false, "redeem from none white listed beneficiary should revert");
      } catch(error) {
        helpers.assertVMException(error);
      }
    });

    it("enable is onlyOwner", async () => {
      let testSetup = await setup(accounts);
      await testSetup.fixedReputationAllocation.addBeneficiary(accounts[0]);
      try {
        await testSetup.fixedReputationAllocation.enable({from:accounts[1]});
        assert(false, "enable is onlyOwner");
      } catch(error) {
        helpers.assertVMException(error);
      }
    });

    it("cannot initialize twice", async () => {
        let testSetup = await setup(accounts);
        try {
             await testSetup.fixedReputationAllocation.initialize(testSetup.org.avatar.address,
                                                                     100,
                                                                    100,
                                                                    accounts[0]);
             assert(false, "cannot initialize twice");
           } catch(error) {
             helpers.assertVMException(error);
           }
    });
});
