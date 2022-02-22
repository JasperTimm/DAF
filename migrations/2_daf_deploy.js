const DAFFactory = artifacts.require("DAFFactory");
const DAFToken = artifacts.require("DAFToken");
const DAFVoting = artifacts.require("DAFVoting");
const ERC20 = artifacts.require("ERC20");
const ProxySwapRouter = artifacts.require("ProxySwapRouter");
const USDC_ADDR = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";

module.exports = async function (deployer, network, accounts) {
  BN = web3.utils.BN

  await deployer.deploy(ProxySwapRouter)
  const router = await ProxySwapRouter.deployed()
  //ProxySwapRouter is used as both router and oracle
  await deployer.deploy(DAFFactory, router.address, router.address, {gas: 0xfffffffff})
  const factory = await DAFFactory.deployed()
  await factory.createDAFToken("DAF Token", "DAF", USDC_ADDR)
  const tokenAddr = await factory.tokenList(0)
  const token = await DAFToken.at(tokenAddr)

  //Transfer a little of the USDC to ProxySwapRouter for swap differences
  await USDC.transfer(router.address, 100000 * 10 ** (await USDC.decimals()))

  //Buy some DAF tokens
  await USDC.approve(token.address, 0xfffffffff)
  const buyAmt = (new BN(10)).pow(new BN(18)).mul(new BN(1000))
  await token.buy(buyAmt)
  
};
