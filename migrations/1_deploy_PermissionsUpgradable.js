const PU = artifacts.require("PermissionsUpgradable");

module.exports = async function (deployer, network, accounts) {
    console.log("Network: " + network);
    console.log("Accounts: " + accounts);

    await deployer.deploy(PU, accounts[0]);
};
