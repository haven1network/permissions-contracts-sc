pragma solidity ^0.5.3;

import "./RoleManager.sol";
import "./AccountManager.sol";
import "./VoterManager.sol";
import "./NodeManager.sol";
import "./OrgManager.sol";
import "./PermissionsUpgradable.sol";

/// @title Permissions Implementation Contract
///
/// @notice This contract holds implementation logic for all permissions related
/// functionality. This can be called into only by the `PermissionsInterface`
/// contract.
contract PermissionsImplementation {
    AccountManager private accountManager;
    RoleManager private roleManager;
    VoterManager private voterManager;
    NodeManager private nodeManager;
    OrgManager private orgManager;
    PermissionsUpgradable private permUpgradable;

    string private adminOrg;
    string private adminRole;
    string private orgAdminRole;

    uint256 private fullAccess = 3;

    /// @dev Used to track the initial network boot up. Once the initial boot
    /// up is complete, this value will be set to `true`.
    bool private networkBoot = false;

    event PermissionsInitialized(bool _networkBootStatus);

    /// @notice Modifier to confirm that caller is the interface contract.
    modifier onlyInterface() {
        require(
            msg.sender == permUpgradable.getPermInterface(),
            "can be called by interface contract only"
        );
        _;
    }

    /// @notice Modifier to confirm that caller is the upgradable contract.
    modifier onlyUpgradeable() {
        require(msg.sender == address(permUpgradable), "invalid caller");
        _;
    }

    /// @notice Modifier to confirm if the network boot status is equal to the
    /// passed value.
    ///
    /// @param _status The status to check.
    modifier networkBootStatus(bool _status) {
        require(networkBoot == _status, "Incorrect network boot status");
        _;
    }

    /// @notice Modifier to confirm that the account passed is the network admin
    /// account.
    ///
    /// @param _account The account to check.
    modifier networkAdmin(address _account) {
        require(
            isNetworkAdmin(_account) == true,
            "account is not a network admin account"
        );
        _;
    }

    /// @notice Modifier to confirm that the account passed is org admin account.
    ///
    /// @param _account The account to check.
    /// @param _orgId The org ID to which the account belongs.
    modifier orgAdmin(address _account, string memory _orgId) {
        require(
            isOrgAdmin(_account, _orgId) == true,
            "account is not a org admin account"
        );
        _;
    }

    /// @notice Modifier to confirm that an org does not exist.
    ///
    /// @param _orgId The org ID to check.
    modifier orgNotExists(string memory _orgId) {
        require(_checkOrgExists(_orgId) != true, "org exists");
        _;
    }

    /// @notice Modifier to confirm that an org exists.
    ///
    /// @param _orgId The org ID to check.
    modifier orgExists(string memory _orgId) {
        require(_checkOrgExists(_orgId) == true, "org does not exist");
        _;
    }

    /// @notice Modifier to check if an org is in approved status.
    ///
    /// @param _orgId The org ID to check.
    modifier orgApproved(string memory _orgId) {
        require(checkOrgApproved(_orgId) == true, "org not in approved status");
        _;
    }

    /// @notice Constructor accepts the contracts addresses of other deployed
    /// contracts of the permissions model.
    ///
    /// @param _permUpgradable  Address of Permissions Upgradable contract
    /// @param _orgManager      Address of Org Manager contract
    /// @param _rolesManager    Address of Role Manager contract
    /// @param _accountManager  Address of Account Manager contract
    /// @param _voterManager    Address of Voter Manager contract
    /// @param _nodeManager     Address of Node Manager contract
    constructor(
        address _permUpgradable,
        address _orgManager,
        address _rolesManager,
        address _accountManager,
        address _voterManager,
        address _nodeManager
    ) public {
        permUpgradable = PermissionsUpgradable(_permUpgradable);
        orgManager = OrgManager(_orgManager);
        roleManager = RoleManager(_rolesManager);
        accountManager = AccountManager(_accountManager);
        voterManager = VoterManager(_voterManager);
        nodeManager = NodeManager(_nodeManager);
    }

    // -------------------------------------------------------------------------
    // Initial Setup Functions

    /// @notice For permissions it is necessary to define:
    /// -   the initial Admin Org ID;
    /// -   the Network Admin Role ID; and
    /// -   the Default Org Admin Role ID.
    //
    /// This function sets these values at the time of network boot up.
    ///
    /// @param _nwAdminOrg  The Network Admin Org ID.
    /// @param _nwAdminRole The default Network Admin Role ID.
    /// @param _oAdminRole  The default Org Admin Role ID.
    ///
    /// @dev This function will be executed only once as part of the boot up.
    function setPolicy(
        string calldata _nwAdminOrg,
        string calldata _nwAdminRole,
        string calldata _oAdminRole
    ) external onlyInterface networkBootStatus(false) {
        adminOrg = _nwAdminOrg;
        adminRole = _nwAdminRole;
        orgAdminRole = _oAdminRole;
    }

    /// @notice When migrating implementation contract, the values of these key
    /// values need to be set from the previous implementation contract. This
    /// function allows these values to be set.
    ///
    /// @param _nwAdminOrg          The Network Admin Org ID.
    /// @param _nwAdminRole         The Admin Role ID.
    /// @param _oAdminRole          The default Org Admin Role ID.
    /// @param _networkBootStatus   The network boot status.
    function setMigrationPolicy(
        string calldata _nwAdminOrg,
        string calldata _nwAdminRole,
        string calldata _oAdminRole,
        bool _networkBootStatus
    ) external onlyUpgradeable networkBootStatus(false) {
        adminOrg = _nwAdminOrg;
        adminRole = _nwAdminRole;
        orgAdminRole = _oAdminRole;
        networkBoot = _networkBootStatus;
    }

    /// @notice Called at the time of network initialization. It:
    /// -   Sets up the Network Admin Org with allowed sub org depth and breadth;
    /// -   Creates the Network Admin for the Network Admin Org; and
    /// -   Sets the default values required by Account Manager contract.
    ///
    /// @param _breadth  The number of sub orgs allowed at parent level.
    /// @param _depth    The levels of sub org nesting allowed at parent level.
    function init(
        uint256 _breadth,
        uint256 _depth
    ) external onlyInterface networkBootStatus(false) {
        orgManager.setUpOrg(adminOrg, _breadth, _depth);
        roleManager.addRole(adminRole, adminOrg, fullAccess, true, true);
        accountManager.setDefaults(adminRole, orgAdminRole);
    }

    /// @notice As a part of network initialization, add all nodes which are
    /// part of static-nodes.json as nodes belonging to network admin org.
    ///
    /// @param _enodeId     The enode ID.
    /// @param _ip          The IP of the node.
    /// @param _port        The TCP port of the node.
    /// @param _raftport    The raft port of the node.
    function addAdminNode(
        string calldata _enodeId,
        string calldata _ip,
        uint16 _port,
        uint16 _raftport
    ) external onlyInterface networkBootStatus(false) {
        nodeManager.addAdminNode(_enodeId, _ip, _port, _raftport, adminOrg);
    }

    /// @notice As a part of network initialization, add all accounts which are
    /// passed via permission-config.json as network administrator accounts.
    ///
    /// @param _account The account's address.
    function addAdminAccount(
        address _account
    ) external onlyInterface networkBootStatus(false) {
        // Only one admin should exist.
        // Because this function is only callable during the boot up phase,
        // there should be no accounts yet.
        require(
            accountManager.getNumberOfAccounts() == 0,
            "Admin already exists"
        );

        // Prev:
        // require(!_checkOrgAdminExists(adminOrg), "Admin already exists");
        // ^ This only checks for existence of org admin, this will not be true,
        // because we block the creation of org admins.
        updateVoterList(adminOrg, _account, true);
        accountManager.assignAdminRole(_account, adminOrg, adminRole, 2);
    }

    /// @notice Once the network initialization is complete, this function sets
    /// the network boot status to true.
    ///
    /// @return The network boot status.
    ///
    /// @dev This will be called only once from geth as a part of network
    ///initialization.
    function updateNetworkBootStatus()
        external
        onlyInterface
        networkBootStatus(false)
        returns (bool)
    {
        networkBoot = true;
        emit PermissionsInitialized(networkBoot);
        return networkBoot;
    }

    /// @notice Adds a new organization to the network. It:
    /// -   Creates an Org record and marks it as pending approval;
    /// -   Adds the passed node to the Node Manager contract;
    /// -   Adds the account with the Org Admin role to the account manager
    ///     contracts; and
    /// -   Creates voting record for approval by other network admin accounts.
    ///
    /// @param _orgId       A unique organization ID.
    /// @param _enodeId     The enode ID linked to the organization.
    /// @param _ip          The IP of the node.
    /// @param _port        The TCP port of the node.
    /// @param _raftport    The raft port of node.
    /// @param _account     The Account ID. This will have the org admin privileges.
    /// @param _caller      The address of the account that called the function.
    ///
    /// @dev We have removed assigning `_account` as the orgAdmin as only one
    /// admin is allowed.
    function addOrg(
        string memory _orgId,
        string memory _enodeId,
        string memory _ip,
        uint16 _port,
        uint16 _raftport,
        address _account,
        address _caller
    ) public onlyInterface {
        require(networkBoot == true, "Incorrect network boot status");
        require(
            isNetworkAdmin(_caller) == true,
            "account is not a network admin account"
        );

        voterManager.addVotingItem(adminOrg, _orgId, _enodeId, _caller, 1);
        orgManager.addOrg(_orgId);
        nodeManager.addNode(_enodeId, _ip, _port, _raftport, _orgId);
    }

    /// @notice Allows the Network Admin to approvae an Org record that is
    /// currently pending approval. Once majority votes are received, the org is
    /// marked as approved.
    ///
    /// @param _orgId       The unique organization ID.
    /// @param _enodeId     The enode ID linked to the organization.
    /// @param _ip          The IP of the node.
    /// @param _port        The TCP port of the node.
    /// @param _raftport    The raft port of the node.
    /// @param _account     The Account ID. This will have the org admin privileges.
    /// @param _caller      The address of the account that called the function.
    ///
    /// @dev We have removed assigning `_account` as the orgAdmin as only one
    /// admin is allowed.
    function approveOrg(
        string memory _orgId,
        string memory _enodeId,
        string memory _ip,
        uint16 _port,
        uint16 _raftport,
        address _account,
        address _caller
    ) public onlyInterface {
        require(
            isNetworkAdmin(_caller) == true,
            "account is not a network admin account"
        );
        require(_checkOrgStatus(_orgId, 1) == true, "Nothing to approve");

        if ((processVote(adminOrg, _caller, 1))) {
            orgManager.approveOrg(_orgId);
            roleManager.addRole(orgAdminRole, _orgId, fullAccess, true, true);
            nodeManager.approveNode(_enodeId, _ip, _port, _raftport, _orgId);
        }
    }

    /// @notice Creates a sub org under a given parent org.
    ///
    /// @param _pOrgId      The parent org ID under which the sub org is being added.
    /// @param _orgId       A unique ID for the sub organization.
    /// @param _enodeId     The enode ID linked to the sub organization.
    /// @param _ip          The IP of the node.
    /// @param _port        The TCP port of the node.
    /// @param _raftport    The raft port of the node.
    /// @param _caller      The address of the account that called the function.
    ///
    /// @dev `_enodeId` is optional.
    ///
    /// @dev The parent org ID should contain the complete org hierarchy from
    /// master org ID to the immediate parent. The org hierarchy is separated by
    /// a `.` - For example, if master org ABC has a sub organization SUB1, then
    /// while creating the sub organization at SUB1 level, the parent org should
    /// be given as `ABC.SUB1`.
    function addSubOrg(
        string calldata _pOrgId,
        string calldata _orgId,
        string calldata _enodeId,
        string calldata _ip,
        uint16 _port,
        uint16 _raftport,
        address _caller
    ) external onlyInterface orgExists(_pOrgId) orgAdmin(_caller, _pOrgId) {
        orgManager.addSubOrg(_pOrgId, _orgId);
        string memory pOrgId = string(abi.encodePacked(_pOrgId, ".", _orgId));

        if (bytes(_enodeId).length > 0) {
            nodeManager.addOrgNode(_enodeId, _ip, _port, _raftport, pOrgId);
        }
    }

    /// @notice Updates the org status. It updates the org status and adds a
    /// voting item for network admins to approve.
    ///
    /// @param _orgId   The unique ID of the organization.
    /// @param _action  The action to undertake.
    /// @param _caller  The address of the account that called the function.
    ///
    /// @dev Available Actions:
    /// -   1 for suspending; or
    /// -   2 for removing a suspension.
    function updateOrgStatus(
        string calldata _orgId,
        uint256 _action,
        address _caller
    ) external onlyInterface networkAdmin(_caller) {
        uint256 pendingOp;
        pendingOp = orgManager.updateOrg(_orgId, _action);
        voterManager.addVotingItem(adminOrg, _orgId, "", address(0), pendingOp);
    }

    /// @notice Approves an org status change. The org status is changed once
    /// the majority votes are received from network admin accounts.
    ///
    /// @param _orgId   The unique ID for the sub organization.
    /// @param _action  The action to undertake.
    /// @param _caller  The address of the account that called the function.
    ///
    /// @dev Available Actions:
    /// -   1 for suspending; or
    /// -   2 for removing a suspension.
    function approveOrgStatus(
        string calldata _orgId,
        uint256 _action,
        address _caller
    ) external onlyInterface networkAdmin(_caller) {
        require((_action == 1 || _action == 2), "Operation not allowed");
        uint256 pendingOp;
        uint256 orgStatus;

        if (_action == 1) {
            pendingOp = 2;
            orgStatus = 3;
        } else if (_action == 2) {
            pendingOp = 3;
            orgStatus = 5;
        }

        require(
            _checkOrgStatus(_orgId, orgStatus) == true,
            "operation not allowed"
        );

        if ((processVote(adminOrg, _caller, pendingOp))) {
            orgManager.approveOrgStatusUpdate(_orgId, _action);
        }
    }

    // -------------------------------------------------------------------------
    // Role Related Functions

    /// @notice Adds a new role definition to an organization. Can only be
    /// executed by the Org Admin.
    ///
    /// @param _roleId  A unique ID for the role.
    /// @param _orgId   The unique ID of the organization to which the role belongs.
    /// @param _access  The account access type allowed for the role.
    /// @param _voter   Indicates if the role is voter role or not.
    /// @param _admin   Indicates if the role is an admin role.
    /// @param _caller  The address of the account that called the function.
    ///
    /// @dev Account access type can have of the following four values:
    /// -   0: Read only
    /// -   1: value transfer
    /// -   2: contract deploy
    /// -   3: full access
    /// -   4: contract call
    /// -   5: value transfer and contract call
    /// -   6: value transfer and contract deploy
    /// -   7: contract call and deploy
    function addNewRole(
        string calldata _roleId,
        string calldata _orgId,
        uint256 _access,
        bool _voter,
        bool _admin,
        address _caller
    ) external onlyInterface orgApproved(_orgId) orgAdmin(_caller, _orgId) {
        // Add new roles can be created by org admins only
        roleManager.addRole(_roleId, _orgId, _access, _voter, _admin);
    }

    /// @notice Removes a role definition from an organization. Can only be
    /// executed by the Org Admin.
    ///
    /// @param _roleId  The unique ID for the role.
    /// @param _orgId   The unique ID of the organization to which the role belongs.
    /// @param _caller  The address of the account that called the function.
    function removeRole(
        string calldata _roleId,
        string calldata _orgId,
        address _caller
    ) external onlyInterface orgApproved(_orgId) orgAdmin(_caller, _orgId) {
        require(
            ((keccak256(abi.encode(_roleId)) !=
                keccak256(abi.encode(adminRole))) &&
                (keccak256(abi.encode(_roleId)) !=
                    keccak256(abi.encode(orgAdminRole)))),
            "admin roles cannot be removed"
        );
        roleManager.removeRole(_roleId, _orgId);
    }

    // -------------------------------------------------------------------------
    // Account Related Functions

    /// @notice Assigns the Network Admin / Org Admin role to an account.
    /// Can only be executed by Network Admin accounts. It assigns the role to
    /// the accounts and creates voting record for network admin accounts.
    ///
    /// @param _orgId   The unique ID of the organization to which the account belongs.
    /// @param _account The account ID.
    /// @param _roleId  The role ID to be assigned to the account.
    /// @param _caller  The address of the account that called the function.
    function assignAdminRole(
        string calldata _orgId,
        address _account,
        string calldata _roleId,
        address _caller
    ) external onlyInterface orgExists(_orgId) networkAdmin(_caller) {
        // Block attempts to assign any role other than network admin.
        require(
            keccak256(abi.encode(_roleId)) == keccak256(abi.encode(adminRole)),
            "can only assign network admin role"
        );

        accountManager.assignAdminRole(_account, _orgId, _roleId, 1);

        // Add the voting item.
        voterManager.addVotingItem(adminOrg, _orgId, "", _account, 4);
    }

    /// @notice Approves Network Admin / Org Admin role assigment.
    /// Can only be executed by Metwork Admin accounts.
    ///
    /// @param _orgId   The unique ID of the organization to which the account belongs.
    /// @param _account The account ID to make a new admin.
    /// @param _caller  The address of the account that called the function.
    ///
    /// @dev After the transfer of admin rights, please assign the old admin a
    /// new non admin role with assignAccountRole
    function approveAdminRole(
        string calldata _orgId,
        address _account,
        address _caller
    ) external onlyInterface networkAdmin(_caller) {
        // Added a check to ensure that the account being approved is subject of voting
        (, , address newAdmin, ) = voterManager.getPendingOpDetails(_orgId);

        require(
            newAdmin == _account,
            "new admin is not the account being approved"
        );

        if ((processVote(adminOrg, _caller, 4))) {
            // There must only be one admin. So this will always trigger at the first call.
            // This also makes the _caller the old admin

            // Remove the existing admin from its role and the voter list.
            // For removal of orgAdmin rights, assigning the current admin the orgAdmin role.
            accountManager.assignAdminRole(_caller, _orgId, orgAdminRole, 1); // Status 1 = suspended.

            // Approve to properly set as org admin
            accountManager.addNewAdmin(_orgId, _caller); // approved to status 2

            // Now revoking the old admin from the orgAdmin role
            accountManager.removeExistingAdmin(_orgId); // revoked to status 6
            updateVoterList(adminOrg, _caller, false);

            // Because org admin is never actually removed in orgAdminIndex, we
            // first override it with the new admin.
            //
            // This will replace orgAdminIndex with the new admin, the old admin
            // is now only a revoked (status 6) org admin.
            //
            // It is advised to assign the old orgAdmin a new role with
            // assignAccountRole after this to fully clear his role.
            accountManager.assignAdminRole(_account, _orgId, orgAdminRole, 1); // Status 1 = suspended.
            accountManager.addNewAdmin(_orgId, _account);

            // Assign back as network admin
            accountManager.assignAdminRole(_account, _orgId, adminRole, 1);

            // Approve the new admiin and add to the the voter list.
            accountManager.addNewAdmin(_orgId, _account);
            updateVoterList(adminOrg, _account, true);
        }
    }

    /// @notice Updates account status. Can only be executed by an Org Admin.
    ///
    /// @param _orgId   The unique ID of the organization to which the account belongs.
    /// @param _account The account ID.
    /// @param _action  The action to undertake.
    /// @param _caller  The address of the account that called the function.
    ///
    /// @dev Available Actions:
    /// -   1: Suspend;
    /// -   2: Activate; or
    /// -   3: Blacklist.
    ///
    /// @dev This function must not be used to alter the status of the admin
    /// account. `accountManager.updateAccountStatus` will check this.
    function updateAccountStatus(
        string calldata _orgId,
        address _account,
        uint256 _action,
        address _caller
    ) external onlyInterface orgAdmin(_caller, _orgId) {
        // Ensure that the action passed to this call is proper and is not
        // called with action 4 and 5 which are actions for blacklisted account
        // recovery.
        require(
            (_action == 1 || _action == 2 || _action == 3),
            "invalid action. operation not allowed"
        );

        // Will revert if the account is the admin account.
        accountManager.updateAccountStatus(_orgId, _account, _action);
    }

    // -------------------------------------------------------------------------
    // Node Related Functions

    /// @notice Adds a new node to the organization. Can only be called by an
    /// Org Admin.
    ///
    /// @param _orgId       The unique ID of the organization to which the account belongs.
    /// @param _enodeId     The enode ID being added to the org.
    /// @param _ip          The IP of the node.
    /// @param _port        The TCP port of the node.
    /// @param _raftport    The raft port of the node.
    /// @param _caller      The address of the account that called the function.
    function addNode(
        string memory _orgId,
        string memory _enodeId,
        string memory _ip,
        uint16 _port,
        uint16 _raftport,
        address _caller
    ) public onlyInterface orgApproved(_orgId) {
        // Check that the node is not part of another org
        require(
            isOrgAdmin(_caller, _orgId) == true,
            "account is not a org admin account"
        );

        nodeManager.addOrgNode(_enodeId, _ip, _port, _raftport, _orgId);
    }

    /// @notice Updates a node's status. Can only be called by an Org Admin.
    ///
    /// @param _orgId       The unique ID of the organization to which the account belongs.
    /// @param _enodeId     The enode ID being added to the org.
    /// @param _ip          The IP of the node.
    /// @param _port        The TCP port of the node.
    /// @param _raftport    The raft port of the node.
    /// @param _action      The action to undertake.
    /// @param _caller      The address of the account that called the function.
    ///
    /// @dev Available Actions:
    /// -   1: Deactivate;
    /// -   2: Activate; or
    /// -   3: Blacklist.
    function updateNodeStatus(
        string memory _orgId,
        string memory _enodeId,
        string memory _ip,
        uint16 _port,
        uint16 _raftport,
        uint256 _action,
        address _caller
    ) public onlyInterface {
        require(
            isOrgAdmin(_caller, _orgId) == true,
            "account is not a org admin account"
        );

        // Ensure that the action passed to this call is proper and is not
        // called with action 4 and 5 which are actions for blacklisted node
        // recovery.
        require(
            (_action == 1 || _action == 2 || _action == 3),
            "invalid action. operation not allowed"
        );

        nodeManager.updateNodeStatus(
            _enodeId,
            _ip,
            _port,
            _raftport,
            _orgId,
            _action
        );
    }

    /// @notice Initiates blacklisted nodes recovery. Can only be called by a
    /// Network Admin.
    ///
    /// @param _orgId       The unique ID of the organization to which the account belongs.
    /// @param _enodeId     The enode ID being added to the org.
    /// @param _ip          The IP of the node.
    /// @param _port        The TCP port of the node.
    /// @param _raftport    The raft port of the node.
    /// @param _caller      The address of the account that called the function.
    ///
    /// @dev This function creates a voting record for other network admins to
    /// approve the operation. The recovery is complete only after majority voting.
    function startBlacklistedNodeRecovery(
        string memory _orgId,
        string memory _enodeId,
        string memory _ip,
        uint16 _port,
        uint16 _raftport,
        address _caller
    ) public onlyInterface networkAdmin(_caller) {
        // Update the node status as recovery initiated. Action for this is 4.
        nodeManager.updateNodeStatus(
            _enodeId,
            _ip,
            _port,
            _raftport,
            _orgId,
            4
        );

        // Add a voting record with pending op of 5 which corresponds to
        // blacklisted node recovery.
        voterManager.addVotingItem(adminOrg, _orgId, _enodeId, address(0), 5);
    }

    /// @notice Approves blacklisted nodes recovery. Can only be called by a
    /// Network Admin.
    ///
    /// @param _orgId       The unique ID of the organization to which the account belongs.
    /// @param _enodeId     The enode ID being added to the org.
    /// @param _ip          The IP of the node.
    /// @param _port        The TCP port of the node.
    /// @param _raftport    The raft port of the node.
    /// @param _caller      The address of the account that called the function.
    function approveBlacklistedNodeRecovery(
        string memory _orgId,
        string memory _enodeId,
        string memory _ip,
        uint16 _port,
        uint16 _raftport,
        address _caller
    ) public onlyInterface networkAdmin(_caller) {
        // Check if majority votes are received. pending op type is passed as 5
        // which stands for black listed node recovery
        if ((processVote(adminOrg, _caller, 5))) {
            // Update the node to active.
            nodeManager.updateNodeStatus(
                _enodeId,
                _ip,
                _port,
                _raftport,
                _orgId,
                5
            );
        }
    }

    /// @notice Initaite blacklisted account recovery. Can only be called by a
    /// Network Admin.
    /// @param _orgId   The unique ID of the organization to which the account belongs.
    /// @param _account The account ID being recovered.
    /// @param _caller  The address of the account that called the function.
    ///
    /// @dev this function creates a voting record for other network admins to
    /// approve the operation. The recovery is complete only after majority voting.
    function startBlacklistedAccountRecovery(
        string calldata _orgId,
        address _account,
        address _caller
    ) external onlyInterface networkAdmin(_caller) {
        // Update the account status as recovery initiated. Action for this is 4.
        accountManager.updateAccountStatus(_orgId, _account, 4);

        // Add a voting record with pending op of 5 which corresponds to
        // blacklisted account recovery.
        voterManager.addVotingItem(adminOrg, _orgId, "", _account, 6);
    }

    /// @notice Approves blacklisted account recovery. Can only be called by a
    /// Network Admin.
    ///
    /// @param _orgId   The unique ID of the organization to which the account belongs.
    /// @param _account The account ID being recovered.
    /// @param _caller  The address of the account that called the function.
    function approveBlacklistedAccountRecovery(
        string calldata _orgId,
        address _account,
        address _caller
    ) external onlyInterface networkAdmin(_caller) {
        // Check if majority votes are received. Pending op type is passed as 6
        // which stands for black listed account recovery.
        if ((processVote(adminOrg, _caller, 6))) {
            // Update the account back to active.
            accountManager.updateAccountStatus(_orgId, _account, 5);
        }
    }

    /// @notice Fetches the network boot status.
    /// @return The network boot status.
    function getNetworkBootStatus() external view returns (bool) {
        return networkBoot;
    }

    /// @notice Fetches the details of any pending approval activities for the
    /// network admin organization.
    ///
    /// @param _orgId The unique ID of the organization.
    ///
    /// @return The org ID.
    /// @return The enode ID.
    /// @return The account.
    /// @return The operation type.
    function getPendingOp(
        string calldata _orgId
    ) external view returns (string memory, string memory, address, uint256) {
        return voterManager.getPendingOpDetails(_orgId);
    }

    /// @notice Assigns a role ID to the account. Can only be executed by an Org
    /// Admin.
    ///
    /// @param _account The account ID.
    /// @param _orgId   The organization ID to which the account belongs.
    /// @param _roleId  The role ID to be assigned to the account.
    /// @param _caller  The address of the account that called the function.
    function assignAccountRole(
        address _account,
        string memory _orgId,
        string memory _roleId,
        address _caller
    ) public onlyInterface orgAdmin(_caller, _orgId) orgApproved(_orgId) {
        require(
            validateAccount(_account, _orgId) == true,
            "operation cannot be performed"
        );
        require(_roleExists(_roleId, _orgId) == true, "role does not exists");

        // Added a check to make sure that the account is not the active admin
        // (status 2). Revert so they can not be demoted with this function.
        string memory accountRole = accountManager.getAccountRole(_account);
        bytes32 hashedAccountRole = keccak256(abi.encode(accountRole));
        if (
            hashedAccountRole == keccak256(abi.encode(orgAdminRole)) ||
            hashedAccountRole == keccak256(abi.encode(adminRole))
        ) {
            uint256 accountStatus = accountManager.getAccountStatus(_account);
            require(accountStatus != 2, "account is the active admin");
        }

        bool admin = roleManager.isAdminRole(
            _roleId,
            _orgId,
            _getUltimateParent(_orgId)
        );

        accountManager.assignAccountRole(_account, _orgId, _roleId, admin);
    }

    /// @notice Checks if an account is a Network Admin.
    ///
    /// @param _account The acconut to check.
    ///
    /// @return True if the account is a Network Admin, false otherwise.
    function isNetworkAdmin(address _account) public view returns (bool) {
        return (keccak256(
            abi.encode(accountManager.getAccountRole(_account))
        ) == keccak256(abi.encode(adminRole)));
    }

    /// @notice Checks if an account is an Org Admin.
    ///
    /// @param _account The account to check.
    /// @param _orgId   The organization ID.
    ///
    /// @return True if the account is an Org Admin, false otherwise.
    function isOrgAdmin(
        address _account,
        string memory _orgId
    ) public view returns (bool) {
        if (
            accountManager.checkOrgAdmin(
                _account,
                _orgId,
                _getUltimateParent(_orgId)
            )
        ) {
            return true;
        }

        return
            roleManager.isAdminRole(
                accountManager.getAccountRole(_account),
                _orgId,
                _getUltimateParent(_orgId)
            );
    }

    /// @notice Validates if an account exists and, if it exists, checks whether
    /// it belongs to the given organization.
    ///
    /// @param _account The account to check.
    /// @param _orgId   The organization ID.
    ///
    /// @return True if the account exists and belongs to the given organization,
    /// false otherwise.
    function validateAccount(
        address _account,
        string memory _orgId
    ) public view returns (bool) {
        return accountManager.validateAccount(_account, _orgId);
    }

    /// @notice Updates the voter list at a network level. Will be called
    /// whenever an account is assigned a Network Admin role or an account that
    /// has a Network Admin role is being assigned a different role.
    ///
    /// @param _orgId   The org ID to which the account belongs.
    /// @param _account The account which needs to be added/removed as voter.
    /// @param _add     Indicates whether this is an add or delete operation.
    ///
    /// @dev `_add` of `true` will add the account to the voter list, `false`
    /// will delete it.
    function updateVoterList(
        string memory _orgId,
        address _account,
        bool _add
    ) internal {
        if (_add) {
            voterManager.addVoter(_orgId, _account);
        } else {
            voterManager.deleteVoter(_orgId, _account);
        }
    }

    /// @notice Allows a Network Admin to process the vote of a pending item.
    ///
    /// @param _orgId       The org ID of the caller.
    /// @param _caller      The address of the account that called the function.
    /// @param _pendingOp   The pending operation for which the approval is being done.
    ///
    /// @return True if the vote was successful, false otherwise.
    ///
    /// @dev The list of pending ops are managed in voter manager contract.
    function processVote(
        string memory _orgId,
        address _caller,
        uint256 _pendingOp
    ) internal returns (bool) {
        return voterManager.processVote(_orgId, _caller, _pendingOp);
    }

    /// @notice Returns various permissions policy related parameters.
    ///
    /// @return The Admin Org ID.
    /// @return The default Network Admin role.
    /// @return The default Org Admin role.
    /// @return The network boot status.
    function getPolicyDetails()
        external
        view
        returns (string memory, string memory, string memory, bool)
    {
        return (adminOrg, adminRole, orgAdminRole, networkBoot);
    }

    /// @notice Checks if an org exists.
    ///
    /// @param _orgId The org ID to check.
    ///
    /// @return True if the org exists, false otherwise.
    function _checkOrgExists(
        string memory _orgId
    ) internal view returns (bool) {
        return orgManager.checkOrgExists(_orgId);
    }

    /// @notice Checks if an org is approved.
    ///
    /// @param _orgId The org ID to check.
    ///
    /// @return True if the org is approved, false otherwise.
    function checkOrgApproved(
        string memory _orgId
    ) internal view returns (bool) {
        return orgManager.checkOrgStatus(_orgId, 2);
    }

    /// @notice Checks if an org has a given status.
    ///
    /// @param _orgId   The org ID.
    /// @param _status  The status to check.
    ///
    /// @return True if the org is of the given status, false otherwise.
    function _checkOrgStatus(
        string memory _orgId,
        uint256 _status
    ) internal view returns (bool) {
        return orgManager.checkOrgStatus(_orgId, _status);
    }

    /// @notice Checks if an Org Admin exists for a given org.
    ///
    /// @param _orgId The org ID to check.
    ///
    /// @return True if an Org Admin exists, false otherwise.
    function _checkOrgAdminExists(
        string memory _orgId
    ) internal view returns (bool) {
        return accountManager.orgAdminExists(_orgId);
    }

    /// @notice Checks if a given role ID exists for the provided org ID.
    ///
    /// @param _roleId  The role ID to check.
    /// @param _orgId   The org ID to check.
    ///
    /// @return True if the given role exists for the provided org, false otherwise.
    function _roleExists(
        string memory _roleId,
        string memory _orgId
    ) internal view returns (bool) {
        return
            roleManager.roleExists(_roleId, _orgId, _getUltimateParent(_orgId));
    }

    /// @notice Checks if a given role ID for an org is a voter role.
    ///
    /// @param _roleId  The role ID to check.
    /// @param _orgId   The org ID to check.
    ///
    /// @return True if the role ID for the org is a voter role, false otherwise.
    function _isVoterRole(
        string memory _roleId,
        string memory _orgId
    ) internal view returns (bool) {
        return
            roleManager.isVoterRole(
                _roleId,
                _orgId,
                _getUltimateParent(_orgId)
            );
    }

    /// @notice Returns the ultimate parent for a given org ID.
    ///
    /// @param _orgId   The org ID.
    ///
    /// @return The ultimate parent org ID for the given org ID.
    function _getUltimateParent(
        string memory _orgId
    ) internal view returns (string memory) {
        return orgManager.getUltimateParent(_orgId);
    }

    /// @notice Checks if whether a node is allowed to connect.
    ///
    /// @param _enodeId The enode ID.
    /// @param _ip      The IP of the node.
    /// @param _port    The TCP port of the node.
    ///
    /// @return True if the node can connect, false otherwise.
    function connectionAllowed(
        string calldata _enodeId,
        string calldata _ip,
        uint16 _port
    ) external view returns (bool) {
        if (!networkBoot) {
            return true;
        }
        return nodeManager.connectionAllowed(_enodeId, _ip, _port);
    }

    /// @notice Checks if an account is allowed to transact or not.
    ///
    /// @param _sender      The source account.
    /// @param _target      The target account.
    /// @param _value       The value being transferred.
    /// @param _gasPrice    The gas price.
    /// @param _gasLimit    The gas limit.
    /// @param _payload     The payload for transactions on contracts.
    ///
    /// @return True if the transaction is allowed, false otherwise.
    function transactionAllowed(
        address _sender,
        address _target,
        uint256 _value,
        uint256 _gasPrice,
        uint256 _gasLimit,
        bytes calldata _payload
    ) external view returns (bool) {
        if (!networkBoot) {
            return true;
        }

        if (accountManager.getAccountStatus(_sender) == 2) {
            (string memory act_org, string memory act_role) = accountManager
                .getAccountOrgRole(_sender);
            string memory act_uOrg = _getUltimateParent(act_org);

            if (orgManager.checkOrgActive(act_org)) {
                if (isNetworkAdmin(_sender) || isOrgAdmin(_sender, act_org)) {
                    return true;
                }

                uint256 typeOfxn = 1;
                if (_target == address(0)) {
                    typeOfxn = 2;
                } else if (_payload.length > 0) {
                    typeOfxn = 3;
                }

                return
                    roleManager.transactionAllowed(
                        act_role,
                        act_org,
                        act_uOrg,
                        typeOfxn
                    );
            }
        }

        return false;
    }
}
