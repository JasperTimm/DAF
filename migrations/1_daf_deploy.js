const DAFFactory = artifacts.require("DAFFactory");
const ERC20 = artifacts.require("ERC20");
const ProxySwapRouter = artifacts.require("ProxySwapRouter");
const USDC_ADDR = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(ProxySwapRouter)
  const router = await ProxySwapRouter.deployed()
  //ProxySwapRouter is used as both router and oracle
  await deployer.deploy(DAFFactory, router.address, router.address, {gas: 0xfffffffff})
  const factory = await DAFFactory.deployed()
  await factory.createDAFToken("DAF Token", "DAF", USDC_ADDR)

  //Transfer all USDC to account 0 if we haven't already
  bigUSDC = "0x55fe002aeff02f77364de339a1292923a15844b8"
  USDC = await ERC20.at(USDC_ADDR)
  bigUSDCAmt = await USDC.balanceOf(bigUSDC)
  if (bigUSDCAmt > 0) {
    await USDC.transfer(accounts[0], bigUSDCAmt, {from: bigUSDC})
  }

  //Transfer a little of the USDC to ProxySwapRouter for swap differences
  await USDC.transfer(router.address, 100000 * 10 ** (await USDC.decimals()))
};
