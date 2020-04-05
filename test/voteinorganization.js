const helpers = require("./helpers");
const VoteInOrganization = artifacts.require('./VoteInOrganizationScheme.sol');
const ERC20Mock = artifacts.require('./test/ERC20Mock.sol');

const AbsoluteVoteExecuteMock = artifacts.require("./AbsoluteVoteExecuteMock.sol");
const GenesisProtocolCallbacksMock = artifacts.require("./GenesisProtocolCallbacksMock.sol");
const Reputation = artifacts.require("./Reputation.sol");

class VoteInOrganizationParams {
  constructor() {
  }
}

var registration;
const setupVoteInOrganizationParams = async function(
                                            accounts,
                                            genesisProtocol = false,
                                            tokenAddress = 0,
                                            avatarAddress
                                            ) {
  var voteInOrganizationParams = new VoteInOrganizationParams();
    voteInOrganizationParams.paramsHash = helpers.NULL_HASH;
  if (genesisProtocol === true){
    voteInOrganizationParams.votingMachine = await helpers.setupGenesisProtocol(accounts,tokenAddress,helpers.NULL_ADDRESS);
    voteInOrganizationParams.initdata = await new web3.eth.Contract(registration.voteInOrganization.abi)
      .methods
      .initialize(avatarAddress,
        voteInOrganizationParams.votingMachine.genesisProtocol.address,
        voteInOrganizationParams.votingMachine.params)
      .encodeABI();
    }
  else {
      voteInOrganizationParams.votingMachine = await helpers.setupAbsoluteVote(helpers.NULL_ADDRESS,50);
      voteInOrganizationParams.initdata = await new web3.eth.Contract(registration.voteInOrganization.abi)
      .methods
      .initialize(avatarAddress,
        voteInOrganizationParams.votingMachine.absoluteVote.address,
        voteInOrganizationParams.votingMachine.params)
      .encodeABI();
  }

  return voteInOrganizationParams;
};

const setup = async function (accounts,reputationAccount=0,genesisProtocol = false,tokenAddress=0) {
   var testSetup = new helpers.TestSetup();
   testSetup.fee = 10;
   testSetup.standardTokenMock = await ERC20Mock.new(accounts[1],100);
   registration = await helpers.registerImplementation();
   testSetup.reputationArray = [200,100,700];
   testSetup.proxyAdmin = accounts[5];
   if (reputationAccount === 0) {
    testSetup.org = await helpers.setupOrganizationWithArraysDAOFactory(testSetup.proxyAdmin,
      accounts,
      registration,
      [accounts[0],accounts[1],accounts[2]],
      [1000,1000,1000],
      testSetup.reputationArray);
   } else {
    testSetup.org = await helpers.setupOrganizationWithArraysDAOFactory(testSetup.proxyAdmin,
      accounts,
      registration,
      [accounts[0],accounts[1],reputationAccount],
      [1000,1000,1000],
      testSetup.reputationArray);
   }

   testSetup.voteInOrganizationParams= await setupVoteInOrganizationParams(
                                                                           accounts,
                                                                           genesisProtocol,
                                                                           tokenAddress,
                                                                           testSetup.org.avatar.address);
   var permissions = "0x00000010";

   var tx = await registration.daoFactory.setSchemes(
    testSetup.org.avatar.address,
    [web3.utils.fromAscii("VoteInOrganization")],
    testSetup.voteInOrganizationParams.initdata,
    [helpers.getBytesLength(testSetup.voteInOrganizationParams.initdata)],
    [permissions],
    "metaData",{from:testSetup.proxyAdmin});

    testSetup.voteInOrganization = await VoteInOrganization.at(tx.logs[1].args._scheme);

   return testSetup;
};

contract('VoteInOrganizationScheme', accounts => {
  before(function() {
     helpers.etherForEveryone(accounts);
  });

     it("proposeVote log", async function() {
       var testSetup = await setup(accounts);

       var anotherTestSetup =  await setup(accounts);
       var absoluteVoteExecuteMock = await AbsoluteVoteExecuteMock.new();
       await absoluteVoteExecuteMock.initialize(testSetup.org.reputation.address,
                                               anotherTestSetup.voteInOrganizationParams.votingMachine.absoluteVote.address);

       var tx = await absoluteVoteExecuteMock.propose(2,
                                                      anotherTestSetup.voteInOrganizationParams.votingMachine.params,
                                                      anotherTestSetup.org.avatar.address,
                                                      accounts[0],helpers.NULL_ADDRESS);

       const proposalId = await helpers.getProposalId(tx,anotherTestSetup.voteInOrganizationParams.votingMachine.absoluteVote, 'NewProposal');
       tx = await testSetup.voteInOrganization.proposeVote(
                                                           anotherTestSetup.voteInOrganizationParams.votingMachine.absoluteVote.address,
                                                           proposalId,1,helpers.NULL_HASH);
       assert.equal(tx.logs.length, 1);
       assert.equal(tx.logs[0].event, "NewVoteProposal");
       assert.equal(tx.logs[0].args._vote, 1);
      });

   it("execute proposeVote -no decision - proposal data delete", async function() {
     var testSetup = await setup(accounts);

     var anotherTestSetup =  await setup(accounts);
     var absoluteVoteExecuteMock = await AbsoluteVoteExecuteMock.new();
     await absoluteVoteExecuteMock.initialize(testSetup.org.reputation.address,
                                              anotherTestSetup.voteInOrganizationParams.votingMachine.absoluteVote.address);
     var tx = await absoluteVoteExecuteMock.propose(2,
                                                                        anotherTestSetup.voteInOrganizationParams.votingMachine.params,
                                                                        anotherTestSetup.org.avatar.address,
                                                                        accounts[0],
                                                                        helpers.NULL_ADDRESS);
     const originalProposalId = await helpers.getProposalId(tx,anotherTestSetup.voteInOrganizationParams.votingMachine.absoluteVote, 'NewProposal');

     tx = await testSetup.voteInOrganization.proposeVote(
                                                         anotherTestSetup.voteInOrganizationParams.votingMachine.absoluteVote.address,
                                                         originalProposalId,1,helpers.NULL_HASH);
     var proposalId = await helpers.getValueFromLogs(tx, '_proposalId');
     await testSetup.voteInOrganizationParams.votingMachine.absoluteVote.vote(proposalId,0,0,helpers.NULL_ADDRESS,{from:accounts[2]});
     //check organizationsProposals after execution
     var organizationProposal = await testSetup.voteInOrganization.organizationProposals(proposalId);
     assert.equal(organizationProposal[0],0x0000000000000000000000000000000000000000);//new contract address
    });

    it("execute proposeVote -positive decision - proposal data delete", async function() {
      var testSetup = await setup(accounts);

      var anotherTestSetup =  await setup(accounts,testSetup.org.avatar.address);
      //mint reputation to avatar in the other dao.
      var absoluteVoteExecuteMock = await AbsoluteVoteExecuteMock.new();
      await absoluteVoteExecuteMock.initialize(anotherTestSetup.org.reputation.address,
                                               anotherTestSetup.voteInOrganizationParams.votingMachine.absoluteVote.address);
      var tx = await absoluteVoteExecuteMock.propose(2,
                                                                         anotherTestSetup.voteInOrganizationParams.votingMachine.params,
                                                                         anotherTestSetup.org.avatar.address,
                                                                         accounts[0],
                                                                         helpers.NULL_ADDRESS);
      const originalProposalId = await helpers.getProposalId(tx,anotherTestSetup.voteInOrganizationParams.votingMachine.absoluteVote, 'NewProposal');

      tx = await testSetup.voteInOrganization.proposeVote(
                                                          anotherTestSetup.voteInOrganizationParams.votingMachine.absoluteVote.address,
                                                          originalProposalId,1,helpers.NULL_HASH);
      var proposalId = await helpers.getValueFromLogs(tx, '_proposalId');
      var organizationProposal = await testSetup.voteInOrganization.organizationProposals(proposalId);
      assert.equal(organizationProposal[0],anotherTestSetup.voteInOrganizationParams.votingMachine.absoluteVote.address);//new contract address
      await testSetup.voteInOrganizationParams.votingMachine.absoluteVote.vote(proposalId,1,0,helpers.NULL_ADDRESS,{from:accounts[2]});
      //check organizationsProposals after execution
      organizationProposal = await testSetup.voteInOrganization.organizationProposals(proposalId);
      assert.equal(organizationProposal[0],0x0000000000000000000000000000000000000000);//new contract address
     });

     it("execute proposeVote -positive decision - check action", async function() {
       var testSetup = await setup(accounts);

       var anotherTestSetup =  await setup(accounts,testSetup.org.avatar.address);
       var absoluteVoteExecuteMock = await AbsoluteVoteExecuteMock.new();
       await absoluteVoteExecuteMock.initialize(anotherTestSetup.org.reputation.address,
                                                anotherTestSetup.voteInOrganizationParams.votingMachine.absoluteVote.address);
        var tx = await absoluteVoteExecuteMock.propose(2,
                                                                          anotherTestSetup.voteInOrganizationParams.votingMachine.params,
                                                                          anotherTestSetup.org.avatar.address,
                                                                          accounts[0],
                                                                          helpers.NULL_ADDRESS);

       const originalProposalId = await helpers.getProposalId(tx,anotherTestSetup.voteInOrganizationParams.votingMachine.absoluteVote, 'NewProposal');
       tx = await testSetup.voteInOrganization.proposeVote(
                                                           anotherTestSetup.voteInOrganizationParams.votingMachine.absoluteVote.address,
                                                           originalProposalId,1,helpers.NULL_HASH);
       var proposalId = await helpers.getValueFromLogs(tx, '_proposalId');
       await testSetup.voteInOrganizationParams.votingMachine.absoluteVote.vote(proposalId,1,0,helpers.NULL_ADDRESS,{from:accounts[2]});
       await helpers.checkVoteInfo(anotherTestSetup.voteInOrganizationParams.votingMachine.absoluteVote,originalProposalId, testSetup.org.avatar.address, [1, anotherTestSetup.reputationArray[2]]);
     });

     it("execute proposeVote -positive decision - check action - with GenesisProtocol", async function() {
        var standardTokenMock = await ERC20Mock.new(accounts[0],1000);
        var testSetup = await setup(accounts,0,true,standardTokenMock.address);

        var anotherTestSetup =  await setup(accounts,0,true,standardTokenMock.address);
        var reputation = await Reputation.new();
        await reputation.initialize(accounts[0]);
        await reputation.mint(testSetup.org.avatar.address,100);

        var genesisProtocolCallbacksMock = await GenesisProtocolCallbacksMock.new();
        await genesisProtocolCallbacksMock.initialize(reputation.address,
                                                      standardTokenMock.address,
                                                      anotherTestSetup.voteInOrganizationParams.votingMachine.genesisProtocol.address);
        await reputation.transferOwnership(genesisProtocolCallbacksMock.address);
        var tx = await genesisProtocolCallbacksMock.propose(2,
                                                                           anotherTestSetup.voteInOrganizationParams.votingMachine.params,
                                                                           anotherTestSetup.org.avatar.address,
                                                                           accounts[0],
                                                                           helpers.NULL_ADDRESS);
        var  originalProposalId = await helpers.getValueFromLogs(tx, '_proposalId');
        tx = await testSetup.voteInOrganization.proposeVote(
                                                            anotherTestSetup.voteInOrganizationParams.votingMachine.genesisProtocol.address,
                                                            originalProposalId,1,helpers.NULL_HASH);
        var proposalId = await helpers.getValueFromLogs(tx, '_proposalId');
        await testSetup.voteInOrganizationParams.votingMachine.genesisProtocol.vote(proposalId,1,0,helpers.NULL_ADDRESS,{from:accounts[2]});
        await helpers.checkVoteInfo(anotherTestSetup.voteInOrganizationParams.votingMachine.genesisProtocol,originalProposalId, testSetup.org.avatar.address, [1, 100]);
     });
});
