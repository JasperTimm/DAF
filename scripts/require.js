
module.exports = {
    tot: async function(token) {
        return (await token.totalSupply()).toString()
    },
    bal: async function(token, addr) {
        return (await token.balanceOf(addr)).toString()
    },
    init: async function(self) {
        with(self) {
            BN = web3.utils.BN
            factory = await DAFFactory.deployed()
            router = await ProxySwapRouter.deployed()
            USDC = await ERC20.at("0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48")
            wBTC = await ERC20.at("0x2260fac5e5542a773aa44fbcfedf7c193bc2c599")
            USDC_FACTOR = 10 ** (await USDC.decimals())
            usdcWBTCPool = "0x99ac8ca7087fa4a2a1fb6357269965a2014abc35"
            bigUSDC = "0x55fe002aeff02f77364de339a1292923a15844b8"
            await USDC.transfer(accounts[0], await USDC.balanceOf(bigUSDC), {from: bigUSDC})
            DAF_TOKEN = await DAFToken.at(await factory.tokenList(0))
            dafVoteAddr = await DAF_TOKEN.dafVoting()
            DAF_VOTE = await DAFVoting.at(dafVoteAddr)

            const dafAmt = (new BN(10)).pow(new BN(await DAF_TOKEN.decimals())).mul(new BN(1000))
            await USDC.approve(DAF_TOKEN.address, dafAmt)
            await DAF_TOKEN.buy(dafAmt)

            Object.assign(self, this)
        }       
    },
    createAndExecuteProposal: async function(self) {
        with(self) {
            const SHARE_FACTOR = await DAF_TOKEN.SHARE_FACTOR()
            await DAF_VOTE.createProposal({tokenAddr: wBTC.address, holdingShare: (0.5 * SHARE_FACTOR), swapPool: usdcWBTCPool})
            //TODO: should get the ID of the proposal created from the resp logs
            const propId = 0
            console.log(`Done! propId is ${propId}`)
            console.log(`Done! prop is:`)
            console.log(await DAF_VOTE.proposalMap(0))

            console.log("Voting for proposal...")
            await DAF_VOTE.voteForProposal(propId)
            console.log("Done!")
        }
    }
}