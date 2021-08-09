
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
            DAF = await DAFToken.deployed()

            Object.assign(self, this)
        }       
    },
    execBuy: async function(self) {
        with(self) {
            const big = "0x55fe002aeff02f77364de339a1292923a15844b8"
            const usdcAmt = "1000000000"
            const usdcWBTCPool = "0x99ac8ca7087fa4a2a1fb6357269965a2014abc35"
            const SHARE_DECIMAL = 100000000

            await USDC.transfer(accounts[0], usdcAmt, {from: big})
            await USDC.approve(DAF.address, usdcAmt)
            await DAF.buy(usdcAmt)
            await DAF.newHolding(wBTC.address, 0.5 * SHARE_DECIMAL, usdcWBTCPool)            
        }
    }
}