const DAFFactory = artifacts.require("DAFFactory");
const ERC20 = artifacts.require("ERC20");
const USDC_ADDR = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(DAFFactory)
  const factory = await DAFFactory.deployed()
  await factory.createDAFToken("DAF Token", "DAF", USDC_ADDR)

  //Transfer all USDC to account 0
  bigUSDC = "0x55fe002aeff02f77364de339a1292923a15844b8"
  USDC = await ERC20.at(USDC_ADDR)
  await USDC.transfer(accounts[0], await USDC.balanceOf(bigUSDC), {from: bigUSDC})
};
