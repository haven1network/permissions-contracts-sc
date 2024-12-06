const fs = require('fs');

const PU = artifacts.require("PermissionsUpgradable");
const AccountManager = artifacts.require("AccountManager");
const NodeManager = artifacts.require("NodeManager");
const OrgManager = artifacts.require("OrgManager");
const RoleManager = artifacts.require("RoleManager");
const VoterManager = artifacts.require("VoterManager");
const PermissionsImplementation = artifacts.require("PermissionsImplementation");
const PermissionsInterface = artifacts.require("PermissionsInterface");

module.exports = async function (deployer, network, accounts) {
    console.log("Network: " + network);
    console.log("Accounts: " + accounts);

    const pu = await PU.deployed();

    await deployer.deploy(OrgManager, pu.address);
    const orgManager = await OrgManager.deployed();

    await deployer.deploy(RoleManager, pu.address);
    const roleManager = await RoleManager.deployed();

    await deployer.deploy(AccountManager, pu.address);
    const accountManager = await AccountManager.deployed();

    await deployer.deploy(VoterManager, pu.address);
    const voterManager = await VoterManager.deployed();

    await deployer.deploy(NodeManager, pu.address);
    const nodeManager = await NodeManager.deployed();

    await deployer.deploy(PermissionsInterface, pu.address);
    const permissionsInterface = await PermissionsInterface.deployed();

    await deployer.deploy(PermissionsImplementation, pu.address, orgManager.address, roleManager.address,
		            accountManager.address, voterManager.address, nodeManager.address);
    const permissionsImplementation = await PermissionsImplementation.deployed();

    await pu.init(permissionsInterface.address, permissionsImplementation.address);

    const filePath = 'permission-config.json';
    const data = {
        permissionModel: 'v2',
        upgradableAddress: pu.address,
        interfaceAddress: permissionsInterface.address,
        implAddress: permissionsImplementation.address,
        nodeMgrAddress: nodeManager.address,
        accountMgrAddress: accountManager.address,
        roleMgrAddress: roleManager.address,
        voterMgrAddress: voterManager.address,
        orgMgrAddress: orgManager.address,
        nwAdminOrg: "HAVEN1",
        nwAdminRole: "ADMIN",
        orgAdminRole: "ORGADMIN",
        accounts: [accounts[0]],
        subOrgBreadth: 3,
        subOrgDepth: 4
    }

    try {
        fs.writeFileSync(filePath, JSON.stringify(data, null, 2))
        console.log(`${filePath} file has been written successfully!`);
    } catch (err) {
        console.error('Error writing JSON file:', err);
    }
};
