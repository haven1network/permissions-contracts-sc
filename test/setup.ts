/* IMPORT NODE MODULES
================================================== */
import { ethers } from "hardhat";
import { type ContractTransactionReceipt } from "ethers";

/* IMPORT TYPES
================================================== */
import type { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import type {
    AccountManager,
    NodeManager,
    OrgManager,
    PermissionsImplementation,
    PermissionsInterface,
    PermissionsUpgradable,
    RoleManager,
    VoterManager,
} from "@typechain";

/* IMPORT CONSTANTS AND UTILS
================================================== */
import {
    deployPermissionsUpgradeable,
    type PermissionsUpgradeableArgs,
} from "@lib/deploy/permissionsUpgradeable";
import { deployOrgManager, type OrgManagerArgs } from "@lib/deploy/orgManager";
import {
    deployRoleManager,
    type RoleManagerArgs,
} from "@lib/deploy/roleManager";
import {
    deployAccountManager,
    type AccountManagerArgs,
} from "@lib/deploy/accountManager";
import {
    deployVoterManager,
    type VoterManagerArgs,
} from "@lib/deploy/voterManager";
import {
    deployNodeManager,
    type NodeManagerArgs,
} from "@lib/deploy/nodeManager";
import {
    deployPermissionsInterface,
    type PermissionsInterfaceArgs,
} from "@lib/deploy/permissionsInterface";
import {
    deployPermissionsImplementation,
    type PermissionsImplementationArgs,
} from "@lib/deploy/permissionsImplementation";

/* TEST DEPLOY
================================================== */
/** @class TestSetup */
export class TestSetup {
    /* Vars
    ======================================== */
    private _isInitialized: boolean;

    private _association!: HardhatEthersSigner;
    private _associationAddress!: string;

    private _accounts!: HardhatEthersSigner[];
    private _accountAddresses!: string[];

    private _permissionsUpgradeable!: PermissionsUpgradable;
    private _permissionsUpgradeableAddress!: string;
    private _permissionsUpgradeableArgs!: PermissionsUpgradeableArgs;

    private _orgManager!: OrgManager;
    private _orgManagerAddress!: string;
    private _orgManagerArgs!: OrgManagerArgs;

    private _roleManager!: RoleManager;
    private _roleManagerAddress!: string;
    private _roleManagerArgs!: RoleManagerArgs;

    private _accountManager!: AccountManager;
    private _accountManagerAddress!: string;
    private _accountManagerArgs!: AccountManagerArgs;

    private _voterManager!: VoterManager;
    private _voterManagerAddress!: string;
    private _voterManagerArgs!: VoterManagerArgs;

    private _nodeManager!: NodeManager;
    private _nodeManagerAddress!: string;
    private _nodeManagerArgs!: NodeManagerArgs;

    private _permissionsInterface!: PermissionsInterface;
    private _permissionsInterfaceAddress!: string;
    private _permissionsInterfaceArgs!: PermissionsInterfaceArgs;

    private _permissionsImplementation!: PermissionsImplementation;
    private _permissionsImplementationAddress!: string;
    private _permissionsImplementationArgs!: PermissionsImplementationArgs;

    public readonly permissionModel = "V2";
    public readonly networkAdminOrg = "HAVEN1";
    public readonly networkAdminRole = "ADMIN";
    public readonly orgAdminRole = "ORGADMIN";
    public readonly subOrgBreadth = 3;
    public readonly subOrgDepth = 4;

    /* Init
    ======================================== */
    /**
     * Private constructor due to requirement for async init work.
     *
     * @constructor
     * @private
     */
    private constructor() {
        this._accounts = [];
        this._accountAddresses = [];

        this._isInitialized = false;
    }

    /**
     * Initializes `TestSetup`. `isInitialized` will return false until
     * this is run.
     *
     * # Error
     *
     * Will throw if any of the deployments are not successful
     *
     * @private
     * @async
     * @throws
     * @method  init
     * @returns {Promise<TestSetup>}
     */
    private async init(): Promise<TestSetup> {
        // Accounts
        // ----------------------------------------
        const [assoc, ...rest] = await ethers.getSigners();

        this._association = assoc;
        this._associationAddress = await assoc.getAddress();

        for (let i = 0; i < rest.length; ++i) {
            this._accounts.push(rest[i]);
            this._accountAddresses.push(await rest[i].getAddress());
        }

        // Permissions Upgradeable
        // ----------------------------------------
        this._permissionsUpgradeableArgs = {
            guardian: this._associationAddress,
        };

        this._permissionsUpgradeable = await deployPermissionsUpgradeable(
            this._permissionsUpgradeableArgs,
            this._association
        );

        this._permissionsUpgradeableAddress =
            await this._permissionsUpgradeable.getAddress();

        // Org Manager
        // ----------------------------------------
        this._orgManagerArgs = {
            permissionsUpgradeable: this._permissionsUpgradeableAddress,
        };

        this._orgManager = await deployOrgManager(
            this._orgManagerArgs,
            this._association
        );

        this._orgManagerAddress = await this._orgManager.getAddress();

        // Role Manager
        // ----------------------------------------
        this._roleManagerArgs = {
            permissionsUpgradeable: this._permissionsUpgradeableAddress,
        };

        this._roleManager = await deployRoleManager(
            this._roleManagerArgs,
            this._association
        );

        this._roleManagerAddress = await this._roleManager.getAddress();

        // Account Manager
        // ----------------------------------------
        this._accountManagerArgs = {
            permissionsUpgradeable: this._permissionsUpgradeableAddress,
        };

        this._accountManager = await deployAccountManager(
            this._accountManagerArgs,
            this._association
        );

        this._accountManagerAddress = await this._accountManager.getAddress();

        // Voter Manager
        // ----------------------------------------
        this._voterManagerArgs = {
            permissionsUpgradeable: this._permissionsUpgradeableAddress,
        };

        this._voterManager = await deployVoterManager(
            this._voterManagerArgs,
            this._association
        );

        this._voterManagerAddress = await this._voterManager.getAddress();

        // Node Manager
        // ----------------------------------------
        this._nodeManagerArgs = {
            permissionsUpgradeable: this._permissionsUpgradeableAddress,
        };

        this._nodeManager = await deployNodeManager(
            this._nodeManagerArgs,
            this._association
        );

        this._nodeManagerAddress = await this._nodeManager.getAddress();

        // Permissions Interface
        // ----------------------------------------
        this._permissionsInterfaceArgs = {
            permissionsUpgradeable: this._permissionsUpgradeableAddress,
        };

        this._permissionsInterface = await deployPermissionsInterface(
            this._permissionsInterfaceArgs,
            this._association
        );

        this._permissionsInterfaceAddress =
            await this._permissionsInterface.getAddress();

        // Permissions Implementation
        // ----------------------------------------
        this._permissionsImplementationArgs = {
            permissionsUpgradeable: this._permissionsUpgradeableAddress,
            orgManager: this._orgManagerAddress,
            rolesManager: this._roleManagerAddress,
            accountManager: this._accountManagerAddress,
            voterManager: this._voterManagerAddress,
            nodeManager: this._voterManagerAddress,
        };

        this._permissionsImplementation = await deployPermissionsImplementation(
            this._permissionsImplementationArgs,
            this._association
        );

        this._permissionsImplementationAddress =
            await this._permissionsImplementation.getAddress();

        // Init
        // ----------------------------------------
        this._isInitialized = true;

        return this;
    }

    /**
     * Static method to create a new instance of `TestSetup`. It runs the required
     * init and returns the instance.
     *
     * @public
     * @static
     * @async
     * @throws
     * @method  create
     * @returns {Promise<TestSetup>} - Promise that resolves to `TestSetup`
     */
    public static async create(): Promise<TestSetup> {
        const instance = new TestSetup();
        return await instance.init();
    }

    /**
     * Initialises the Permissions Upgradeable contract. Not performed on test
     * initialisation so we can test before and after init state.
     *
     * @async
     * @thows
     * @method initPermissionsUpgradeable
     */
    public async initPermissionsUpgradeable(): Promise<ContractTransactionReceipt | null> {
        const txRes = await this._permissionsUpgradeable.init(
            this._permissionsInterfaceAddress,
            this._permissionsImplementationAddress
        );

        return await txRes.wait();
    }

    /**
     * Initialises the Permissions Implementation contract. Not performed on test
     * initialisation so we can test before and after init state.
     *
     * @async
     * @thows
     * @method initPermissionsImpl
     */
    public async initPermissionsImpl(): Promise<ContractTransactionReceipt | null> {
        const txRes = await this._permissionsInterface.init(
            this.subOrgBreadth,
            this.subOrgDepth
        );

        return await txRes.wait();
    }

    /* Getters
    ======================================== */
    /**
     * @method      association
     * @returns     {HardhatEthersSigner}
     * @throws
     */
    public get association(): HardhatEthersSigner {
        this.validateInitialized("association");
        return this._association;
    }

    /**
     * @method      associationAddress
     * @returns     {string}
     * @throws
     */
    public get associationAddress(): string {
        this.validateInitialized("associationAddress");
        return this._associationAddress;
    }

    /**
     * @method      accounts
     * @returns     {HardhatEthersSigner[]}
     * @throws
     */
    public get accounts(): HardhatEthersSigner[] {
        this.validateInitialized("accounts");
        return this._accounts;
    }

    /**
     * @method      accountAddresses
     * @returns     {string[]}
     * @throws
     */
    public get accountAddresses(): string[] {
        this.validateInitialized("accountAddresses");
        return this._accountAddresses;
    }

    /**
     * @method      permissionsUpgradeable
     * @returns     {PermissionsUpgradable}
     * @throws
     */
    public get permissionsUpgradeable(): PermissionsUpgradable {
        this.validateInitialized("permissionsUpgradeable");
        return this._permissionsUpgradeable;
    }

    /**
     * @method      permissionsUpgradeableAddress
     * @returns     {string}
     * @throws
     */
    public get permissionsUpgradeableAddress(): string {
        this.validateInitialized("permissionsUpgradeableAddress");
        return this._permissionsUpgradeableAddress;
    }

    /**
     * @method      permissionsUpgradeableArgs
     * @returns     {PermissionsUpgradeableArgs}
     * @throws
     */
    public get permissionsUpgradeableArgs(): PermissionsUpgradeableArgs {
        this.validateInitialized("permissionsUpgradeableArgs");
        return this._permissionsUpgradeableArgs;
    }

    /**
     * @method      orgManager
     * @returns     {OrgManager}
     * @throws
     */
    public get orgManager(): OrgManager {
        this.validateInitialized("orgManager");
        return this._orgManager;
    }

    /**
     * @method      orgManagerAddress
     * @returns     {string}
     * @throws
     */
    public get orgManagerAddress(): string {
        this.validateInitialized("orgManagerAddress");
        return this._orgManagerAddress;
    }

    /**
     * @method      orgManagerArgs
     * @returns     {OrgManagerArgs}
     * @throws
     */
    public get orgManagerArgs(): OrgManagerArgs {
        this.validateInitialized("orgManagerArgs");
        return this._orgManagerArgs;
    }

    /**
     * @method      roleManager
     * @returns     {RoleManager}
     * @throws
     */
    public get roleManager(): RoleManager {
        this.validateInitialized("roleManager");
        return this._roleManager;
    }

    /**
     * @method      roleManagerAddress
     * @returns     {string}
     * @throws
     */
    public get roleManagerAddress(): string {
        this.validateInitialized("roleManagerAddress");
        return this._roleManagerAddress;
    }

    /**
     * @method      roleManagerArgs
     * @returns     {RoleManagerArgs}
     * @throws
     */
    public get roleManagerArgs(): RoleManagerArgs {
        this.validateInitialized("roleManagerArgs");
        return this._roleManagerArgs;
    }

    /**
     * @method      accountManager
     * @returns     {AccountManager}
     * @throws
     */
    public get accountManager(): AccountManager {
        this.validateInitialized("accountManager");
        return this._accountManager;
    }

    /**
     * @method      accountManagerAddress
     * @returns     {string}
     * @throws
     */
    public get accountManagerAddress(): string {
        this.validateInitialized("accountManagerAddress");
        return this._accountManagerAddress;
    }

    /**
     * @method      accountManagerArgs
     * @returns     {AccountManagerArgs}
     * @throws
     */
    public get accountManagerArgs(): AccountManagerArgs {
        this.validateInitialized("accountManagerArgs");
        return this._accountManagerArgs;
    }

    /**
     * @method      voterManager
     * @returns     {VoterManager}
     * @throws
     */
    public get voterManager(): VoterManager {
        this.validateInitialized("voterManager");
        return this._voterManager;
    }

    /**
     * @method      voterManagerAddress
     * @returns     {string}
     * @throws
     */
    public get voterManagerAddress(): string {
        this.validateInitialized("voterManagerAddress");
        return this._voterManagerAddress;
    }

    /**
     * @method      voterManagerArgs
     * @returns     {VoterManagerArgs}
     * @throws
     */
    public get voterManagerArgs(): VoterManagerArgs {
        this.validateInitialized("voterManagerArgs");
        return this._voterManagerArgs;
    }

    /**
     * @method      nodeManager
     * @returns     {NodeManager}
     * @throws
     */
    public get nodeManager(): NodeManager {
        this.validateInitialized("nodeManager");
        return this._nodeManager;
    }

    /**
     * @method      nodeManagerAddress
     * @returns     {string}
     * @throws
     */
    public get nodeManagerAddress(): string {
        this.validateInitialized("nodeManagerAddress");
        return this._nodeManagerAddress;
    }

    /**
     * @method      nodeManagerArgs
     * @returns     {NodeManagerArgs}
     * @throws
     */
    public get nodeManagerArgs(): NodeManagerArgs {
        this.validateInitialized("nodeManagerArgs");
        return this._nodeManagerArgs;
    }

    /**
     * @method      permissionsInterface
     * @returns     {PermissionsInterface}
     * @throws
     */
    public get permissionsInterface(): PermissionsInterface {
        this.validateInitialized("permissionsInterface");
        return this._permissionsInterface;
    }

    /**
     * @method      permissionsInterfaceAddress
     * @returns     {string}
     * @throws
     */
    public get permissionsInterfaceAddress(): string {
        this.validateInitialized("permissionsInterfaceAddress");
        return this._permissionsInterfaceAddress;
    }

    /**
     * @method      permissionsInterfaceArgs
     * @returns     {PermissionsInterfaceArgs}
     * @throws
     */
    public get permissionsInterfaceArgs(): PermissionsInterfaceArgs {
        this.validateInitialized("permissionsInterfaceArgs");
        return this._permissionsInterfaceArgs;
    }

    /**
     * @method      permissionsImplementation
     * @returns     {PermissionsImplementation}
     * @throws
     */
    public get permissionsImplementation(): PermissionsImplementation {
        this.validateInitialized("permissionsImplementation");
        return this._permissionsImplementation;
    }

    /**
     * @method      permissionsImplementationAddress
     * @returns     {string}
     * @throws
     */
    public get permissionsImplementationAddress(): string {
        this.validateInitialized("permissionsImplementationAddress");
        return this._permissionsImplementationAddress;
    }

    /**
     * @method      permissionsImplementationArgs
     * @returns     {PermissionsImplementationArgs}
     * @throws
     */
    public get permissionsImplementationArgs(): PermissionsImplementationArgs {
        this.validateInitialized("permissionsImplementationArgs");
        return this._permissionsImplementationArgs;
    }

    /**
     *  Validates if the class instance has been initialized.
     *
     *  # Error
     *
     *  Will throw an error if the class instance has not been initialized.
     *
     *  @private
     *  @method     validateInitialized
     *  @param      {string}    method
     *  @throws
     */
    private validateInitialized(method: string): void {
        if (!this._isInitialized) {
            const err = `Deployment not initialized. Call create() before accessing ${method}.`;
            throw new Error(err);
        }
    }
}
