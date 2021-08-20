const { console } = require("../truffle-config")

module.exports = {
    tot: async function(token) {
        return (await token.totalSupply()).toString()
    },
    bal: async function(token, addr) {
        return (await token.balanceOf(addr)).toString()
    },
    init: async function(self) {
        with(self) {
            USDC = await ERC20.at("0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48")
            wBTC = await ERC20.at("0x2260fac5e5542a773aa44fbcfedf7c193bc2c599")
            DAF_TOKEN = await DAFToken.deployed()
            dafVoteAddr = await DAF_TOKEN.dafVoting()
            DAF_VOTE = await DAFVoting.at(dafVoteAddr)

            Object.assign(self, this)
        }       
    },
    execBuy: async function(self) {
        with(self) {
            const big = "0x55fe002aeff02f77364de339a1292923a15844b8"
            const USDC_DECIMAL = await USDC.decimals()
            const usdcAmt = 10000 * (10 ** USDC_DECIMAL)
            const usdcWBTCPool = "0x99ac8ca7087fa4a2a1fb6357269965a2014abc35"
            const SHARE_FACTOR = await DAF_TOKEN.SHARE_FACTOR()
            await USDC.transfer(accounts[0], usdcAmt, {from: big})

            console.log("Buying DAF tokens...")
            await USDC.approve(DAF_TOKEN.address, usdcAmt)
            await DAF_TOKEN.buy(usdcAmt)
            console.log("Done!")

            console.log("Proposing new holding...")
            await DAF_VOTE.proposeNewHolding({tokenAddr: wBTC.address, holdingShare: (0.5 * SHARE_FACTOR), swapPool: usdcWBTCPool})
            //TODO: should get the ID of the proposal created from the resp logs
            const propId = 0
            console.log(`Done! propId is ${propId}`)
            console.log(`Done! prop is:`)
            console.log(await DAF_VOTE.proposalMap(0))

            console.log("Voting for proposal...")
            await DAF_VOTE.voteForProposal(propId)
            console.log("Done!")

            console.log("Executing proposal...")
            await DAF_VOTE.executeProposal(propId)
            console.log("Done!")
        }
    }
}