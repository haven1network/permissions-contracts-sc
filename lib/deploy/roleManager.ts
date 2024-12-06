/* IMPORT NODE MODULES
================================================== */
import { ethers } from "hardhat";

/* IMPORT TYPES
================================================== */
import type { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import type { RoleManager } from "@typechain";

/* TYPES
================================================== */
export type RoleManagerArgs = {
    readonly permissionsUpgradeable: string;
};

/* DEPLOY
================================================== */
/**
 * Deploys the `RoleManager` contract.
 *
 * # Error
 *
 * Will throw an error if the deployment is not successful. The calling code
 * must handle as desired.
 *
 * @async
 * @throws
 * @function    deployRoleManager
 *
 * @param       {RoleManagerArgs}       args
 * @param       {HardhatEthersSigner}   signer
 *
 * @returns     {Promise<RoleManager>}
 */
export async function deployRoleManager(
    args: RoleManagerArgs,
    signer: HardhatEthersSigner
): Promise<RoleManager> {
    const f = await ethers.getContractFactory("RoleManager", signer);
    const c = await f.deploy(args.permissionsUpgradeable);
    return c.waitForDeployment();
}
