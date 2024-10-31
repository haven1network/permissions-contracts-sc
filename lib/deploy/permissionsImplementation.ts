/* IMPORT NODE MODULES
================================================== */
import { ethers } from "hardhat";

/* IMPORT TYPES
================================================== */
import type { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import type { PermissionsImplementation } from "@typechain";

/* TYPES
================================================== */
export type PermissionsImplementationArgs = {
    readonly permissionsUpgradeable: string;
    readonly orgManager: string;
    readonly rolesManager: string;
    readonly accountManager: string;
    readonly voterManager: string;
    readonly nodeManager: string;
};

/* DEPLOY
================================================== */
/**
 * Deploys the `PermissionsImplementation` contract.
 *
 * # Error
 *
 * Will throw an error if the deployment is not successful. The calling code
 * must handle as desired.
 *
 * @async
 * @throws
 * @function    deployPermissionsImplementation
 *
 * @param       {PermissionsImplementationArgs}       args
 * @param       {HardhatEthersSigner}   signer
 *
 * @returns     {Promise<PermissionsImplementation>}
 */
export async function deployPermissionsImplementation(
    args: PermissionsImplementationArgs,
    signer: HardhatEthersSigner
): Promise<PermissionsImplementation> {
    const f = await ethers.getContractFactory(
        "PermissionsImplementation",
        signer
    );

    const c = await f.deploy(
        args.permissionsUpgradeable,
        args.orgManager,
        args.rolesManager,
        args.accountManager,
        args.voterManager,
        args.nodeManager
    );
    return c.waitForDeployment();
}
