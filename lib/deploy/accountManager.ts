/* IMPORT NODE MODULES
================================================== */
import { ethers } from "hardhat";

/* IMPORT TYPES
================================================== */
import type { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import type { AccountManager } from "@typechain";

/* TYPES
================================================== */
export type AccountManagerArgs = {
    readonly permissionsUpgradeable: string;
};

/* DEPLOY
================================================== */
/**
 * Deploys the `AccountManager` contract.
 *
 * # Error
 *
 * Will throw an error if the deployment is not successful. The calling code
 * must handle as desired.
 *
 * @async
 * @throws
 * @function    deployAccountManager
 *
 * @param       {AccountManagerArgs}    args
 * @param       {HardhatEthersSigner}   signer
 *
 * @returns     {Promise<AccountManager>}
 */
export async function deployAccountManager(
    args: AccountManagerArgs,
    signer: HardhatEthersSigner
): Promise<AccountManager> {
    const f = await ethers.getContractFactory("AccountManager", signer);
    const c = await f.deploy(args.permissionsUpgradeable);
    return c.waitForDeployment();
}
