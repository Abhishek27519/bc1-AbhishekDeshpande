const Migrations = artifacts.require("Product_Trace");

module.exports = function (deployer) {
  deployer.deploy(Migrations);
};