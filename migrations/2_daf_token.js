const DAFToken = artifacts.require("DAFToken");
const USDC_ADDR = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";

module.exports = function (deployer) {
  deployer.deploy(DAFToken, "DAF", "DAF Token", USDC_ADDR);
};
