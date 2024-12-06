/* IMPORT NODE MODULES
================================================== */
import { ethers } from "hardhat";

/* IMPORT TYPES
================================================== */
import type { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import type { PermissionsUpgradable } from "@typechain";

/* TYPES
================================================== */
export type PermissionsUpgradeableArgs = {
    readonly guardian: string;
};

/* DEPLOY
================================================== */
/**
 * Deploys the `PermissionsUpgradable` contract.
 *
 * # Error
 *
 * Will throw an error if the deployment is not successful. The calling code
 * must handle as desired.
 *
 * @async
 * @throws
 * @function    deployPermissionsUpgradeable
 *
 * @param       {PermissionsUpgradeableArgs}    args
 * @param       {HardhatEthersSigner}           signer
 *
 * @returns     {Promise<PermissionsUpgradable>}
 */
export async function deployPermissionsUpgradeable(
    args: PermissionsUpgradeableArgs,
    signer: HardhatEthersSigner
): Promise<PermissionsUpgradable> {
    const f = await ethers.getContractFactory("PermissionsUpgradable", signer);
    const c = await f.deploy(args.guardian);
    return c.waitForDeployment();
}
