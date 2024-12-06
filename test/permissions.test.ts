/* IMPORT NODE MODULESsimpl.test
================================================== */
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";

/* IMPORT CONSTANTS AND UTILS
================================================== */
import { TestSetup } from "./setup";

/* CONSTANTS AND UTILS
================================================== */
const PermissionsImplementationErr = {
    ONLY_INTERFACE: "can be called by interface contract only",
    NETWORK_BOOT_STATUS: "Incorrect network boot status",
} as const;

/* TESTS
================================================== */
describe("Permission Implementation", function () {
    /* Setup
    ======================================== */
    async function setup() {
        return await TestSetup.create();
    }

    /* Deployment and Initialization
    ======================================== */
    describe("Deployment", function () {
        it("Should have a deployment address", async function () {
            const t = await loadFixture(setup);
            expect(t.permissionsImplementationAddress).to.have.length(42);
        });
    });

    /* Policy Management
    ======================================== */
    describe("Policy Management", function () {
        it("Should revert if setPolicy is called directly on the Implementation", async function () {
            const t = await loadFixture(setup);
            const permImpl = t.permissionsImplementation;
            const err = PermissionsImplementationErr.ONLY_INTERFACE;

            // Initialise the core contracts.
            await t.initPermissionsUpgradeable();

            // Should fail if called directly.
            await expect(
                permImpl.setPolicy(
                    t.networkAdminOrg,
                    t.networkAdminRole,
                    t.orgAdminRole
                )
            ).to.be.revertedWith(err);
        });

        it("Should revert if setPolicy is called after the boot status has been set to true", async function () {
            const t = await loadFixture(setup);
            const permInterface = t.permissionsInterface;
            const err = PermissionsImplementationErr.NETWORK_BOOT_STATUS;

            // Initialise the core contracts.
            await t.initPermissionsUpgradeable();
            await t.initPermissionsImpl();

            // Set network boot stats to `true`.
            const txRes = await permInterface.updateNetworkBootStatus();
            await txRes.wait();

            // Should fail with a boot status of `true`.
            await expect(
                permInterface.setPolicy(
                    t.networkAdminOrg,
                    t.networkAdminRole,
                    t.orgAdminRole
                )
            ).to.be.revertedWith(err);
        });

        it("Should allow the Permissions Interface to set a policy on the Permissions Implementation", async function () {
            const t = await loadFixture(setup);
            const permImpl = t.permissionsImplementation;
            const permInterface = t.permissionsInterface;

            // Initialise the core contracts.
            await t.initPermissionsUpgradeable();
            await t.initPermissionsImpl();

            // At the start, there should be no starting policy.
            const startingPolicy = await permImpl.getPolicyDetails();
            expect(startingPolicy).to.deep.equal(["", "", "", false]);

            // Set a permissions policy.
            const txRes = await permInterface.setPolicy(
                t.networkAdminOrg,
                t.networkAdminRole,
                t.orgAdminRole
            );

            await txRes.wait();

            // Check the new permissions policy.
            // Note that setting a policy does not change the boot status, so we
            // still expect a status of `false` here.
            const endingPolicy = await permImpl.getPolicyDetails();
            expect(endingPolicy).to.deep.equal([
                t.networkAdminOrg,
                t.networkAdminRole,
                t.orgAdminRole,
                false,
            ]);
        });
    });
});
