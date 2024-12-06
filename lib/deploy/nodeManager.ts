/* IMPORT NODE MODULES
================================================== */
import { ethers } from "hardhat";

/* IMPORT TYPES
================================================== */
import type { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import type { NodeManager } from "@typechain";

/* TYPES
================================================== */
export type NodeManagerArgs = {
    readonly permissionsUpgradeable: string;
};

/* DEPLOY
================================================== */
/**
 * Deploys the `NodeManager` contract.
 *
 * # Error
 *
 * Will throw an error if the deployment is not successful. The calling code
 * must handle as desired.
 *
 * @async
 * @throws
 * @function    deployNodeManager
 *
 * @param       {NodeManagerArgs}       args
 * @param       {HardhatEthersSigner}   signer
 *
 * @returns     {Promise<NodeManager>}
 */
export async function deployNodeManager(
    args: NodeManagerArgs,
    signer: HardhatEthersSigner
): Promise<NodeManager> {
    const f = await ethers.getContractFactory("NodeManager", signer);
    const c = await f.deploy(args.permissionsUpgradeable);
    return c.waitForDeployment();
}
