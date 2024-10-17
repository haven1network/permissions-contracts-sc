import { expect } from "chai";
import { ethers } from "hardhat";
import {
    PermissionsImplementation,
    PermissionsInterface,
    PermissionsUpgradable,
    AccountManager,
    NodeManager,
    OrgManager,
    RoleManager,
    VoterManager,
} from "../typechain-types";
import type { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";

describe("PermissionsImplementation", () => {
    let permissionsInterface: PermissionsInterface;
    let permissionsUpgradable: PermissionsUpgradable;
    let permissionsUpgradeableAddress: string;
    let permissionsImplementation: PermissionsImplementation;
    let accountManager: AccountManager;
    let nodeManager: NodeManager;
    let orgManager: OrgManager;
    let roleManager: RoleManager;
    let voterManager: VoterManager;
    let association: HardhatEthersSigner;
    let user: HardhatEthersSigner;
    let attacker: HardhatEthersSigner;

    const adminOrg = "HAVEN1";
    const adminRole = "ADMIN";
    const orgAdminRole = "ORGADMIN";
    const basicRole = "BASIC";

    before("Prepare", async () => {
        [association, user, attacker] = await ethers.getSigners();

        const permissionsUpgradeableFactory = await ethers.getContractFactory(
            "PermissionsUpgradable"
        );
        permissionsUpgradable = await permissionsUpgradeableFactory.deploy(
            association.address
        );
        permissionsUpgradeableAddress =
            await permissionsUpgradable.getAddress();

        const accountManagerFactory = await ethers.getContractFactory(
            "AccountManager"
        );
        accountManager = await accountManagerFactory.deploy(
            permissionsUpgradeableAddress
        );

        const nodeManagerFactory = await ethers.getContractFactory(
            "NodeManager"
        );
        nodeManager = await nodeManagerFactory.deploy(
            permissionsUpgradeableAddress
        );

        const orgManagerFactory = await ethers.getContractFactory("OrgManager");
        orgManager = await orgManagerFactory.deploy(
            permissionsUpgradeableAddress
        );

        const roleManagerFactory = await ethers.getContractFactory(
            "RoleManager"
        );
        roleManager = await roleManagerFactory.deploy(
            permissionsUpgradeableAddress
        );

        const voterManagerFactory = await ethers.getContractFactory(
            "VoterManager"
        );
        voterManager = await voterManagerFactory.deploy(
            permissionsUpgradeableAddress
        );

        const permissionsInterfaceFactory = await ethers.getContractFactory(
            "PermissionsInterface"
        );
        permissionsInterface = await permissionsInterfaceFactory.deploy(
            permissionsUpgradeableAddress
        );

        const PermissionsImplementation = await ethers.getContractFactory(
            "PermissionsImplementation"
        );
        permissionsImplementation = await PermissionsImplementation.deploy(
            permissionsUpgradeableAddress,
            await orgManager.getAddress(),
            await roleManager.getAddress(),
            await accountManager.getAddress(),
            await voterManager.getAddress(),
            await nodeManager.getAddress()
        );

        await permissionsUpgradable.waitForDeployment();
        await permissionsImplementation.waitForDeployment();
        await permissionsInterface.waitForDeployment();
    });

    describe("Set initial admin prior to init", () => {
        it("Successfully init permissions upgradable", async () => {
            await permissionsUpgradable.init(
                await permissionsInterface.getAddress(),
                await permissionsImplementation.getAddress()
            );
        });
        it("Successfully set policy", async () => {
            await permissionsInterface.setPolicy(
                adminOrg,
                adminRole,
                orgAdminRole
            );
            const [ao, ar, oar, networkBoot] =
                await permissionsImplementation.getPolicyDetails();
            expect(ao).to.equal("HAVEN1");
            expect(ar).to.equal("ADMIN");
            expect(oar).to.equal("ORGADMIN");
            expect(networkBoot).to.equal(false);
        });
        it("Revert set admin account if not initialized", async () => {
            // The call will revert, because the network admin role is not set yet in the accountManager
            await expect(
                permissionsInterface.addAdminAccount(association.address)
            ).to.be.revertedWith("can be called to assign admin roles only");
        });
        it("Successfully init", async () => {
            await expect(permissionsInterface.init(0, 0))
                .to.emit(roleManager, "RoleCreated")
                .withArgs(adminRole, adminOrg, 3, true, true); // 3 is full access
        });
        it("Successfully set admin account", async () => {
            await expect(
                permissionsInterface.addAdminAccount(association.address)
            )
                .to.emit(voterManager, "VoterAdded")
                .withArgs(adminOrg, association.address)
                .to.emit(accountManager, "AccountAccessModified")
                .withArgs(association.address, adminOrg, adminRole, true, 2);
        });
        it("Revert if setting up a second admin account", async () => {
            await expect(
                permissionsInterface.addAdminAccount(association.address)
            ).to.be.rejectedWith("Admin already exists");
        });
        it("Initialize network boot status", async () => {
            await expect(permissionsInterface.updateNetworkBootStatus())
                .to.emit(permissionsImplementation, "PermissionsInitialized")
                .withArgs(true);
            const [, , , networkBoot] =
                await permissionsImplementation.getPolicyDetails();
            expect(networkBoot).to.equal(true);
        });
        it("Revert addAdminAccount if network is already initialized", async () => {
            await expect(
                permissionsInterface.addAdminAccount(association.address)
            ).to.be.revertedWith("Incorrect network boot status");
        });
        it("Only admin can assign admin Role", async () => {
            await expect(
                permissionsInterface
                    .connect(user)
                    .assignAdminRole(adminOrg, user.address, adminRole)
            ).to.be.revertedWith("account is not a network admin account");
        });
        it("Revert if trying to assign any role other then network admin", async () => {
            await expect(
                permissionsInterface.assignAdminRole(
                    adminOrg,
                    user.address,
                    orgAdminRole
                )
            ).to.be.revertedWith("can only assign network admin role");
        });
        it("Revert if trying to assign admin to current admin", async () => {
            await expect(
                permissionsInterface.assignAdminRole(
                    adminOrg,
                    association.address,
                    orgAdminRole
                )
            ).to.be.revertedWith("cannot assign admin role to current admin");
        });
        it("Successfully assign admin role", async () => {
            await expect(
                permissionsInterface.assignAdminRole(
                    adminOrg,
                    user.address,
                    adminRole
                )
            )
                .to.emit(accountManager, "AccountAccessModified")
                .withArgs(user.address, adminOrg, adminRole, true, 1)
                .to.emit(voterManager, "VotingItemAdded")
                .withArgs(adminOrg);

            const [addr, org, role, status, oa] =
                await accountManager.getAccountDetails(user.address);
            expect(addr).to.equal(user.address);
            expect(org).to.equal(adminOrg);
            expect(role).to.equal(adminRole);
            expect(status).to.equal(1);
            expect(oa).to.equal(true);
            const [orgId, enodeId, account, opType] =
                await permissionsInterface.getPendingOp(adminOrg);
            expect(orgId).to.equal(adminOrg);
            expect(enodeId).to.equal("");
            expect(account).to.equal(user.address);
            expect(opType).to.equal(4);
        });
        it("Revert if a current vote is still pending for approval", async () => {
            await expect(
                permissionsInterface.assignAdminRole(
                    adminOrg,
                    user.address,
                    adminRole
                )
            ).to.be.revertedWith(
                "items pending for approval. new item cannot be added"
            );
        });
        // HOW TO CANCEL A VOTING??
        // could not find any way to cancel a voting. It looks like it requires additions
        // to the voterManager.
        // If correct, the current state means that after an admin was assigned, it is not
        // possible to start a new voting or cancel a voting, other then approving the
        // vote and therefor confirming it
        it("Revert if trying to approve admin role as non network admin", async () => {
            await expect(
                permissionsInterface
                    .connect(attacker)
                    .approveAdminRole(adminOrg, user.address)
            ).to.be.revertedWith("account is not a network admin account");
        });
        it("Revert if new admin tries to approve himself", async () => {
            // The user will be recognized as admin (since he IS an admin, but of status
            // 1, so pending approval), but he will not have voting power in the voting Manager
            await expect(
                permissionsInterface
                    .connect(user)
                    .approveAdminRole(adminOrg, user.address)
            ).to.be.revertedWith("must be a voter");
        });
        it("Revert if admin account to assign is different then the one in the voting", async () => {
            await expect(
                permissionsInterface.approveAdminRole(
                    adminOrg,
                    attacker.address
                )
            ).to.be.revertedWith("new admin is not the account being approved");
        });
        it("Successfully approve admin role", async () => {
            await expect(
                permissionsInterface.approveAdminRole(adminOrg, user.address)
            )
                .to.emit(voterManager, "VoteProcessed")
                .withArgs(adminOrg)
                .and.to.emit(accountManager, "AccountAccessModified")
                .withArgs(association.address, adminOrg, orgAdminRole, true, 1) // assign org admin
                .and.to.emit(accountManager, "AccountAccessModified")
                .withArgs(association.address, adminOrg, orgAdminRole, true, 2) // approve org admin
                .and.to.emit(accountManager, "AccountAccessModified")
                .withArgs(association.address, adminOrg, orgAdminRole, false, 6) // revoked org admin
                .and.to.emit(voterManager, "VoterDeleted")
                .withArgs(adminOrg, association.address) // removed old admin from voter list
                .and.to.emit(accountManager, "AccountAccessModified")
                .withArgs(user.address, adminOrg, orgAdminRole, true, 1) // assign org admin role to new admin
                .and.to.emit(accountManager, "AccountAccessModified")
                .withArgs(user.address, adminOrg, orgAdminRole, true, 2) // approve org admin role to new admin
                .and.to.emit(accountManager, "AccountAccessModified")
                .withArgs(user.address, adminOrg, adminRole, true, 1) // assign network admin role to new admin
                .and.to.emit(accountManager, "AccountAccessModified")
                .withArgs(user.address, adminOrg, adminRole, true, 2) // approve network admin role to new admin
                .and.to.emit(voterManager, "VoterAdded")
                .withArgs(adminOrg, user.address); // add new admin to voter list

            const role = await accountManager.getAccountRole(user.address);
            expect(role).to.equal(adminRole);
            const status = await accountManager.getAccountStatus(user.address);
            expect(status).to.equal(2);
            expect(await accountManager.orgAdminExists(adminOrg)).to.equal(
                true
            );
            expect(
                await permissionsInterface.isNetworkAdmin(user.address)
            ).to.equal(true);
        });
        it("New admin should be org admin as well", async () => {
            expect(await accountManager.orgAdminExists(adminOrg)).to.equal(
                true
            );
            const isOrgAdmin = await accountManager.checkOrgAdmin(
                user.address,
                adminOrg,
                adminOrg
            );
            expect(isOrgAdmin).to.equal(true);
        });
        it("Old admin should be set as revoked admin", async () => {
            const role = await accountManager.getAccountRole(
                association.address
            );
            expect(role).to.equal(orgAdminRole);
            const status = await accountManager.getAccountStatus(
                association.address
            );
            expect(status).to.equal(6);
        });
        it("Voter list should only consist of the new admin"); // Voter list can not be retrieved from the voteManager in any way, but at least event was proven to have happened in previous test
        it("Revert if trying to add role without admin role", async () => {
            await expect(
                permissionsInterface.addNewRole(
                    basicRole,
                    adminOrg,
                    5,
                    false,
                    false
                )
            ).to.be.revertedWith("account is not a org admin account");
        });
        it("Add new basic role", async () => {
            await expect(
                permissionsInterface
                    .connect(user)
                    .addNewRole(basicRole, adminOrg, 5, false, false)
            )
                .to.emit(roleManager, "RoleCreated")
                .withArgs(basicRole, adminOrg, 5, false, false);
        });
        it("Revert if trying to demote admin account", async () => {
            await expect(
                permissionsInterface
                    .connect(user)
                    .assignAccountRole(user.address, adminOrg, basicRole)
            ).to.be.revertedWith("account is the active admin");
        });
        it("Successfully assign basic role to old admin", async () => {
            await expect(
                permissionsInterface
                    .connect(user)
                    .assignAccountRole(association.address, adminOrg, basicRole)
            )
                .to.emit(accountManager, "AccountAccessModified")
                .withArgs(association.address, adminOrg, basicRole, false, 2);
            const role = await accountManager.getAccountRole(
                association.address
            );
            expect(role).to.equal(basicRole);
            const status = await accountManager.getAccountStatus(
                association.address
            );
            expect(status).to.equal(2);
        });
        it("Revert if trying to create admin or voting role", async () => {
            await expect(
                permissionsInterface
                    .connect(user)
                    .addNewRole(adminRole, adminOrg, 3, true, false)
            ).to.be.revertedWith("cannot create admin or voting roles");
            await expect(
                permissionsInterface
                    .connect(user)
                    .addNewRole(adminRole, adminOrg, 3, false, true)
            ).to.be.revertedWith("cannot create admin or voting roles");
        });
    });

    // describe("Init", () => {
    //     before("Init all", async () => {
    //         await permissionsUpgradable.init(
    //             await permissionsInterface.getAddress(),
    //             await permissionsImplementation.getAddress()
    //         );
    //         await permissionsInterface.init(0, 0);
    //         await permissionsImplementation.init(0, 0);
    //     });
    // });
});
