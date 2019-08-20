const helpers = require('./helpers');
const { MerkleTree } = require('./merkleTree.js');
const DaoCreator = artifacts.require("./DaoCreator.sol");
const ControllerCreator = artifacts.require("./ControllerCreator.sol");
const constants = require('./constants');
var ReputationFromToken = artifacts.require("./ReputationFromToken.sol");
var RepAllocation = artifacts.require("./RepAllocation.sol");

var PolkaCurve = artifacts.require("./PolkaCurve.sol");

const setup = async function (accounts, _initialize = true) {
   var testSetup = new helpers.TestSetup();
   var controllerCreator = await ControllerCreator.new({gas: constants.ARC_GAS_LIMIT});
   testSetup.daoCreator = await DaoCreator.new(controllerCreator.address,{gas:constants.ARC_GAS_LIMIT});
   testSetup.org = await helpers.setupOrganization(testSetup.daoCreator,accounts[0],1000,1000);
   testSetup.repAllocation = await RepAllocation.new();
   await testSetup.repAllocation.addBeneficiary(accounts[0],100);
   await testSetup.repAllocation.addBeneficiary(accounts[1],200);
   await testSetup.repAllocation.addBeneficiary(accounts[2],300);

   testSetup.reputationFromToken = await ReputationFromToken.new();
   testSetup.curve = await PolkaCurve.new();
   if (_initialize === true) {
     await testSetup.reputationFromToken.initialize(testSetup.org.avatar.address,
                                                    testSetup.repAllocation.address,
                                                    testSetup.curve.address);
   }

   var permissions = "0x00000000";
   await testSetup.daoCreator.setSchemes(testSetup.org.avatar.address,[testSetup.reputationFromToken.address],[helpers.NULL_HASH],[permissions],"metaData");
   return testSetup;
};

contract.only('ReputationFromToken and RepAllocation', accounts => {
    it("initialize", async () => {
      let testSetup = await setup(accounts);
      assert.equal(await testSetup.reputationFromToken.tokenContract(),testSetup.repAllocation.address);
      assert.equal(await testSetup.reputationFromToken.avatar(),testSetup.org.avatar.address);
      assert.equal(await testSetup.reputationFromToken.curve(),testSetup.curve.address);
    });

    it("repAllocation is onlyOwner", async () => {
      let testSetup = await setup(accounts);
      try {
        await testSetup.repAllocation.addBeneficiary(accounts[3],1030,{from:accounts[1]});
        assert(false, "repAllocation is onlyOwner");
      } catch(error) {
        helpers.assertVMException(error);
      }

    });

    it("repAllocation cannot allocate after freeze", async () => {
      let testSetup = await setup(accounts);
      await testSetup.repAllocation.addBeneficiary(accounts[3],1030);
      await testSetup.repAllocation.freeze();


      try {
          await testSetup.repAllocation.addBeneficiary(accounts[4],1030);
        assert(false, "cannot allocate after freeze");
      } catch(error) {
        helpers.assertVMException(error);
      }

    });

    it("repAllocation cannot allocate twice", async () => {
      let testSetup = await setup(accounts);
      assert(await testSetup.repAllocation.balanceOf(accounts[1]),200);
      await testSetup.repAllocation.addBeneficiary(accounts[1],1030);
      assert(await testSetup.repAllocation.balanceOf(accounts[1]),200);
    });

    it("repAllocation addBeneficiaries", async () => {
      let testSetup = await setup(accounts);
      let tx = await testSetup.repAllocation.addBeneficiaries([accounts[3],accounts[4]],[300,400]);
      assert.equal(tx.logs.length,2);
    });

    it("repAllocation addBeneficiariesRoot", async () => {
      let testSetup = await setup(accounts);

      // Backend side code:

      const elements = [
        accounts[3] + (100).toString(16).padStart(64, '0'),
        accounts[4] + (200).toString(16).padStart(64, '0'),
      ];
      const merkleTree = new MerkleTree(elements);

      const tx = await testSetup.repAllocation.addBeneficiariesRoot(
        merkleTree.getHexRoot(),
        [accounts[3], accounts[4]],
        [100, 200]
      );
      assert(await testSetup.repAllocation.balanceOf(accounts[3]),0);
      assert(await testSetup.repAllocation.balanceOf(accounts[4]),0);

      // Client side code:

      const beneficiaries = tx.logs[0].args._beneficiaries;
      const amounts = tx.logs[0].args._amounts;

      const elementsOnClientSide = beneficiaries.map((beneficiary, i) =>
        '0x' + beneficiary.substring(2) + amounts[i].toString(16).padStart(64, '0'),
      );
      const merkleTreeOnClientSide = new MerkleTree(elementsOnClientSide);

      await testSetup.repAllocation.revealBeneficiary(beneficiaries[0],amounts[0],merkleTree.getHexRoot(),merkleTreeOnClientSide.getProof(elementsOnClientSide[0]));
      assert(await testSetup.repAllocation.balanceOf(accounts[3]),100);

      await testSetup.repAllocation.revealBeneficiary(beneficiaries[1],amounts[1],merkleTree.getHexRoot(),merkleTreeOnClientSide.getProof(elementsOnClientSide[1]));
      assert(await testSetup.repAllocation.balanceOf(accounts[4]),200);
    });



    it("redeem", async () => {
      let testSetup = await setup(accounts);
      var tx = await testSetup.reputationFromToken.redeem(accounts[1]);
      var total_reputation = await testSetup.curve.TOTAL_REPUTATION();
      var sum_of_sqrt = await testSetup.curve.SUM_OF_SQRTS();
      var expected = Math.floor(((10*total_reputation)/sum_of_sqrt) * 1000000000) * 1000000000;

      assert.equal(tx.logs.length,1);
      assert.equal(tx.logs[0].event,"Redeem");
      assert.equal(tx.logs[0].args._beneficiary,accounts[1]);
      assert.equal(tx.logs[0].args._amount.toString(),expected);
      assert.equal(tx.logs[0].args._sender,accounts[0]);
      assert.equal(await testSetup.org.reputation.balanceOf(accounts[0]),1000);
      assert.equal(await testSetup.org.reputation.balanceOf(accounts[1]),expected);
    });

    it("redeem with no beneficiary", async () => {
      let testSetup = await setup(accounts);
      var tx = await testSetup.reputationFromToken.redeem(helpers.NULL_ADDRESS);
      var total_reputation = await testSetup.curve.TOTAL_REPUTATION();
      var sum_of_sqrt = await testSetup.curve.SUM_OF_SQRTS();
      var expected = Math.floor(((10*total_reputation)/sum_of_sqrt) * 1000000000) * 1000000000;
      assert.equal(tx.logs.length,1);
      assert.equal(tx.logs[0].event,"Redeem");
      assert.equal(tx.logs[0].args._beneficiary,accounts[0]);
      assert.equal(tx.logs[0].args._amount,expected);
      assert.equal(tx.logs[0].args._sender,accounts[0]);
      assert.equal((await testSetup.org.reputation.balanceOf(accounts[0])).toString(),
                  (expected + 1000).toString());
      assert.equal(await testSetup.org.reputation.balanceOf(accounts[1]),0);
    });

    it("cannot initialize twice", async () => {
        let testSetup = await setup(accounts);
        try {
             await testSetup.reputationFromToken.initialize(testSetup.org.avatar.address,
                                                            testSetup.repAllocation.address,
                                                            testSetup.curve.address
                                                            );
             assert(false, "cannot initialize twice");
           } catch(error) {
             helpers.assertVMException(error);
           }
    });
});
