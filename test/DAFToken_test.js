const {
  BN,           // Big Number support
  // constants,    // Common constants, like the zero address and largest integers
  // expectEvent,  // Assertions for emitted events
  // expectRevert, // Assertions for transactions that should fail
} = require('@openzeppelin/test-helpers');
const DAFFactory = artifacts.require("DAFFactory");
const DAFToken = artifacts.require("DAFToken");
const DAFVoting = artifacts.require("DAFVoting");

//Instead of BeforeEach for now, the migration actually does a bunch of things:
// - transfers a bunch of USDC to account[0]
// - creates a standard DAF token in the factory
// - approves USDC and buys some DAF token on account[0]
// - moves a little USDC to the ProxySwapRouter to account for mainnet price swaps

contract("Failed sell test", async accounts => {
  it("should sell DAF tokens", async () => {
    const factory = await DAFFactory.deployed()
    const token = await DAFToken.at(await factory.tokenList(0))
    const voting = await DAFVoting.at(await token.dafVoting())
    const SHARE_FACTOR = await token.SHARE_FACTOR()

    // Buy 10% wBTC
    await voting.createProposal(
      {
        token: "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599",
        holdingShare: 10 * SHARE_FACTOR / 100,
        swapPool: "0x99ac8ca7087fa4a2a1fb6357269965a2014abc35"
      }
    )
    await voting.voteForProposal(0)
    await voting.executeProposal(0)

    // Buy 10% SLR
    await voting.createProposal(
      {
        token: "0x4e9e4ab99cfc14b852f552f5fb3aa68617825b6c",
        holdingShare: 10 * SHARE_FACTOR / 100,
        swapPool: "0xa8d0517ebcb1ecbb4745a4298d75e0592c463396"
      }
    )
    await voting.voteForProposal(1)
    await voting.executeProposal(1)

    // Sell 500 DAF tokens
    const sellAmt = (new BN(10)).pow(new BN(18)).mul(new BN(500))
    const gasEstimate = await token.sell.estimateGas(sellAmt)
    console.log(`gasEstimate is: ${gasEstimate}`)
    await token.sell(sellAmt)

    // // Buy 1000 DAF tokens
    // const buyAmt = (new BN(10)).pow(new BN(18)).mul(new BN(1000))
    // const gasEstimate = await token.buy.estimateGas(buyAmt)
    // console.log(`gasEstimate is: ${gasEstimate}`)
    // await token.buy(buyAmt)
  })
})