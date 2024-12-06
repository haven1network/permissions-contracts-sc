/* IMPORT NODE MODULES
================================================== */
import { ethers } from "hardhat";

/* IMPORT TYPES
================================================== */
import type { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import type { OrgManager } from "@typechain";

/* TYPES
================================================== */
export type OrgManagerArgs = {
    readonly permissionsUpgradeable: string;
};

/* DEPLOY
================================================== */
/**
 * Deploys the `OrgManager` contract.
 *
 * # Error
 *
 * Will throw an error if the deployment is not successful. The calling code
 * must handle as desired.
 *
 * @async
 * @throws
 * @function    deployOrgManager
 *
 * @param       {OrgManagerArgs}        args
 * @param       {HardhatEthersSigner}   signer
 *
 * @returns     {Promise<OrgManager>}
 */
export async function deployOrgManager(
    args: OrgManagerArgs,
    signer: HardhatEthersSigner
): Promise<OrgManager> {
    const f = await ethers.getContractFactory("OrgManager", signer);
    const c = await f.deploy(args.permissionsUpgradeable);
    return c.waitForDeployment();
}
