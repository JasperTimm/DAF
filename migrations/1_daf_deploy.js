const DAFFactory = artifacts.require("DAFFactory");
const USDC_ADDR = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";

module.exports = async function (deployer) {
  await deployer.deploy(DAFFactory)
  const factory = await DAFFactory.deployed()
  await factory.createDAFToken("DAF Token", "DAF", USDC_ADDR)
};
