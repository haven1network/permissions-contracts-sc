/* IMPORT NODE MODULES
================================================== */
import { ethers } from "hardhat";

/* IMPORT TYPES
================================================== */
import type { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import type { PermissionsInterface } from "@typechain";

/* TYPES
================================================== */
export type PermissionsInterfaceArgs = {
    readonly permissionsUpgradeable: string;
};

/* DEPLOY
================================================== */
/**
 * Deploys the `PermissionsInterface` contract.
 *
 * # Error
 *
 * Will throw an error if the deployment is not successful. The calling code
 * must handle as desired.
 *
 * @async
 * @throws
 * @function    deployPermissionsInterface
 *
 * @param       {PermissionsInterfaceArgs}       args
 * @param       {HardhatEthersSigner}   signer
 *
 * @returns     {Promise<PermissionsInterface>}
 */
export async function deployPermissionsInterface(
    args: PermissionsInterfaceArgs,
    signer: HardhatEthersSigner
): Promise<PermissionsInterface> {
    const f = await ethers.getContractFactory("PermissionsInterface", signer);
    const c = await f.deploy(args.permissionsUpgradeable);
    return c.waitForDeployment();
}
