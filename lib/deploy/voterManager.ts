/* IMPORT NODE MODULES
================================================== */
import { ethers } from "hardhat";

/* IMPORT TYPES
================================================== */
import type { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import type { VoterManager } from "@typechain";

/* TYPES
================================================== */
export type VoterManagerArgs = {
    readonly permissionsUpgradeable: string;
};

/* DEPLOY
================================================== */
/**
 * Deploys the `VoterManager` contract.
 *
 * # Error
 *
 * Will throw an error if the deployment is not successful. The calling code
 * must handle as desired.
 *
 * @async
 * @throws
 * @function    deployVoterManager
 *
 * @param       {VoterManagerArgs}    args
 * @param       {HardhatEthersSigner}   signer
 *
 * @returns     {Promise<VoterManager>}
 */
export async function deployVoterManager(
    args: VoterManagerArgs,
    signer: HardhatEthersSigner
): Promise<VoterManager> {
    const f = await ethers.getContractFactory("VoterManager", signer);
    const c = await f.deploy(args.permissionsUpgradeable);
    return c.waitForDeployment();
}
