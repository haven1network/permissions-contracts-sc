pragma solidity ^0.5.3;

import "./PermissionsUpgradable.sol";

/// @title AccountManager
///
/// @notice This contract holds the implementation logic for all account
/// management functionality. This can only be called into by the
/// `PermissionsImplementation` contract.
///
/// There are multiple public view functions exposed. The functions are invoked
/// Quorum for populating permissions data in cache.
///
/// @dev Account status is denoted by a fixed integer value. The values are as
/// below:
///
/// -   0: Not in list
/// -   1: Account pending approval
/// -   2: Active
/// -   3: Inactive
/// -   4: Suspended
/// -   5: Blacklisted
/// -   6: Revoked
/// -   7: Recovery Initiated for blacklisted accounts and pending approval
///     from network admins
///
/// Once the account is blacklisted no further activity on the account is
/// possible.
///
/// When adding a new org admin account to an existing org, the existing org
/// admin account will be in revoked status and can be assigned a new role
/// later.
contract AccountManager {
    PermissionsUpgradable private permUpgradable;

    struct AccountAccessDetails {
        address account;
        string orgId;
        string role;
        uint status;
        bool orgAdmin;
    }

    AccountAccessDetails[] private accountAccessList;
    mapping(address => uint) private accountIndex;
    uint private numAccounts;

    string private adminRole;
    string private orgAdminRole;

    mapping(bytes32 => address) private orgAdminIndex;

    event AccountAccessModified(
        address _account,
        string _orgId,
        string _roleId,
        bool _orgAdmin,
        uint _status
    );

    event AccountAccessRevoked(
        address _account,
        string _orgId,
        string _roleId,
        bool _orgAdmin
    );

    event AccountStatusChanged(address _account, string _orgId, uint _status);

    /// @notice Confirms that the caller is the Permissions Implementation contract.
    modifier onlyImplementation() {
        require(msg.sender == permUpgradable.getPermImpl(), "invalid caller");
        _;
    }

    /// @notice Checks if the account exists and belongs to the given org ID.
    /// @param _orgId   The org ID.
    /// @param _account The account ID.
    modifier accountExists(string memory _orgId, address _account) {
        require((accountIndex[_account]) != 0, "account does not exists");
        require(
            keccak256(
                abi.encode(accountAccessList[_getAccountIndex(_account)].orgId)
            ) == keccak256(abi.encode(_orgId)),
            "account in different org"
        );
        _;
    }

    /// @notice  Sets the PermissionsUpgradable address.
    ///
    /// @param _permUpgradable The PermissionsUpgradable contract address.
    constructor(address _permUpgradable) public {
        permUpgradable = PermissionsUpgradable(_permUpgradable);
    }

    /// @notice Returns the details for a given account.
    ///
    /// @param _account The account for which the details are retrieved.
    ///
    /// @return The account's address.
    /// @return The org ID associated with the account.
    /// @return The role linked to the account.
    /// @return The status of the account.
    /// @return Whether the account is an org admin.
    function getAccountDetails(
        address _account
    )
        external
        view
        returns (address, string memory, string memory, uint, bool)
    {
        if (accountIndex[_account] == 0) {
            return (_account, "NONE", "", 0, false);
        }
        uint aIndex = _getAccountIndex(_account);
        return (
            accountAccessList[aIndex].account,
            accountAccessList[aIndex].orgId,
            accountAccessList[aIndex].role,
            accountAccessList[aIndex].status,
            accountAccessList[aIndex].orgAdmin
        );
    }

    /// @notice Returns the account details for a given account if account is
    /// valid/active.
    ///
    /// @param _account The account for which the details are retrieved.
    ///
    /// @return The org ID associated with the account.
    /// @return The role linked to the account.
    function getAccountOrgRole(
        address _account
    ) external view returns (string memory, string memory) {
        if (accountIndex[_account] == 0) {
            return ("NONE", "");
        }
        uint aIndex = _getAccountIndex(_account);
        return (
            accountAccessList[aIndex].orgId,
            accountAccessList[aIndex].role
        );
    }

    /// @notice Returns the account details at a given index.
    ///
    /// @param  _aIndex account index
    ///
    /// @return The account's address.
    /// @return The org ID associated with the account.
    /// @return The role linked to the account.
    /// @return The status of the account.
    /// @return Whether the account is an org admin.
    function getAccountDetailsFromIndex(
        uint _aIndex
    )
        external
        view
        returns (address, string memory, string memory, uint, bool)
    {
        return (
            accountAccessList[_aIndex].account,
            accountAccessList[_aIndex].orgId,
            accountAccessList[_aIndex].role,
            accountAccessList[_aIndex].status,
            accountAccessList[_aIndex].orgAdmin
        );
    }

    /// @notice Returns the total number of accounts.
    ///
    /// @return The total number of accounts.
    function getNumberOfAccounts() external view returns (uint) {
        return accountAccessList.length;
    }

    /// @notice Called at the time of network initialization to set the Network
    /// and Org Admin roles.
    function setDefaults(
        string calldata _nwAdminRole,
        string calldata _oAdminRole
    ) external onlyImplementation {
        adminRole = _nwAdminRole;
        orgAdminRole = _oAdminRole;
    }

    /// @notice Assigns the Org Admin or Network Admin roles to the given account.
    ///
    /// @param _account The account to assign the role to.
    /// @param _orgId   The org to which the account belongs.
    /// @param _roleId  The role ID to be assigned.
    /// @param _status  The account status to be assigned.
    function assignAdminRole(
        address _account,
        string calldata _orgId,
        string calldata _roleId,
        uint _status
    ) external onlyImplementation {
        require(
            ((keccak256(abi.encode(_roleId)) ==
                keccak256(abi.encode(orgAdminRole))) ||
                (keccak256(abi.encode(_roleId)) ==
                    keccak256(abi.encode(adminRole)))),
            "can be called to assign admin roles only"
        );

        _setAccountRole(_account, _orgId, _roleId, _status, true);
    }

    /// @notice Assigns the role to the given account.
    ///
    /// @param _account     The account to assign the role to.
    /// @param _orgId       The org to which the account belongs.
    /// @param _roleId      The role ID to be assigned.
    /// @param _adminRole   Whether the role is an admin role.
    function assignAccountRole(
        address _account,
        string calldata _orgId,
        string calldata _roleId,
        bool _adminRole
    ) external onlyImplementation {
        require(
            ((keccak256(abi.encode(_roleId)) !=
                keccak256(abi.encode(adminRole))) &&
                (keccak256(abi.encode(abi.encode(_roleId))) !=
                    keccak256(abi.encode(orgAdminRole)))),
            "cannot be called for assigning org admin and network admin roles"
        );
        _setAccountRole(_account, _orgId, _roleId, 2, _adminRole);
    }

    /// @notice Removes an existing admin account. Is called when adding a new
    /// account as an Org Admin account. At the org level there can be one Org
    /// Admin account only.
    ///
    /// @param _orgId The Org ID.
    ///
    /// @return Whether a voter update is required.
    /// @return The account that was removed.
    function removeExistingAdmin(
        string calldata _orgId
    ) external onlyImplementation returns (bool voterUpdate, address account) {
        // Change the status of existing Org Admin to revoked.
        if (orgAdminExists(_orgId)) {
            uint id = _getAccountIndex(
                orgAdminIndex[keccak256(abi.encode(_orgId))]
            );
            accountAccessList[id].status = 6;
            accountAccessList[id].orgAdmin = false;
            emit AccountAccessModified(
                accountAccessList[id].account,
                accountAccessList[id].orgId,
                accountAccessList[id].role,
                accountAccessList[id].orgAdmin,
                accountAccessList[id].status
            );
            return (
                (keccak256(abi.encode(accountAccessList[id].role)) ==
                    keccak256(abi.encode(adminRole))),
                accountAccessList[id].account
            );
        }
        return (false, address(0));
    }

    /// @notice Adds an account as Network Admin or Org Admin.
    ///
    /// @param _orgId   The org ID.
    /// @param _account The account to add.
    ///
    /// @return Whether a voter update is required.
    function addNewAdmin(
        string calldata _orgId,
        address _account
    ) external onlyImplementation returns (bool voterUpdate) {
        // Check if the account role is Org Admin role and the status is pending
        // approval. If yes, then update the status to approved.
        string memory role = getAccountRole(_account);
        uint status = getAccountStatus(_account);
        uint id = _getAccountIndex(_account);
        if (
            (keccak256(abi.encode(role)) ==
                keccak256(abi.encode(orgAdminRole))) && (status == 1)
        ) {
            orgAdminIndex[keccak256(abi.encode(_orgId))] = _account;
        }
        accountAccessList[id].status = 2;
        accountAccessList[id].orgAdmin = true;
        emit AccountAccessModified(
            _account,
            accountAccessList[id].orgId,
            accountAccessList[id].role,
            accountAccessList[id].orgAdmin,
            accountAccessList[id].status
        );
        return (keccak256(abi.encode(accountAccessList[id].role)) ==
            keccak256(abi.encode(adminRole)));
    }

    /// @notice Updates an account's status.
    ///
    /// @param _orgId   The org ID of the account.
    /// @param _account The account's address.
    /// @param _action  The new status of the account.
    ///
    /// @dev The following actions are allowed:
    /// -   1: Suspend the account
    /// -   2: Reactivate a suspended account
    /// -   3: Blacklist an account
    /// -   4: Initiate recovery for black listed account
    /// -   5: Complete recovery of black listed account and update status to active
    function updateAccountStatus(
        string calldata _orgId,
        address _account,
        uint _action
    ) external onlyImplementation accountExists(_orgId, _account) {
        require((_action > 0 && _action < 6), "invalid status change request");

        // Check whether the account is an Org Ddmin. If yes, then do not allow
        // any status change.
        require(
            checkOrgAdmin(_account, _orgId, "") != true,
            "status change not possible for org admin accounts"
        );

        uint newStatus;
        if (_action == 1) {
            // For suspending an account current status should be active.
            require(
                accountAccessList[_getAccountIndex(_account)].status == 2,
                "account is not in active status. operation cannot be done"
            );
            newStatus = 4;
        } else if (_action == 2) {
            // For reactivating a suspended account, current status should be suspended.
            require(
                accountAccessList[_getAccountIndex(_account)].status == 4,
                "account is not in suspended status. operation cannot be done"
            );
            newStatus = 2;
        } else if (_action == 3) {
            require(
                accountAccessList[_getAccountIndex(_account)].status != 5,
                "account is already blacklisted. operation cannot be done"
            );
            newStatus = 5;
        } else if (_action == 4) {
            require(
                accountAccessList[_getAccountIndex(_account)].status == 5,
                "account is not blacklisted. operation cannot be done"
            );
            newStatus = 7;
        } else if (_action == 5) {
            require(
                accountAccessList[_getAccountIndex(_account)].status == 7,
                "account recovery not initiated. operation cannot be done"
            );
            newStatus = 2;
        }

        accountAccessList[_getAccountIndex(_account)].status = newStatus;
        emit AccountStatusChanged(_account, _orgId, newStatus);
    }

    /// @notice Checks if a given account exists and whether it belongs to the
    /// given organization.
    ///
    /// @param _account The account to check.
    /// @param _orgId   The org ID to check.
    ///
    /// @return True if the account does not exists or exists and belongs to the
    /// given org. False otherwise.
    function validateAccount(
        address _account,
        string calldata _orgId
    ) external view returns (bool) {
        if (accountIndex[_account] == 0) {
            return true;
        }
        uint256 id = _getAccountIndex(_account);
        return (keccak256(abi.encode(accountAccessList[id].orgId)) ==
            keccak256(abi.encode(_orgId)));
    }

    /// @notice Checks if an Org Admin account exists for the provided org ID.
    ///
    /// @param _orgId The org ID to check.
    ///
    /// @return True if the Org Admin account exists and is approved. False
    /// otherwise.
    function orgAdminExists(string memory _orgId) public view returns (bool) {
        if (orgAdminIndex[keccak256(abi.encode(_orgId))] != address(0)) {
            address adminAcct = orgAdminIndex[keccak256(abi.encode(_orgId))];
            return getAccountStatus(adminAcct) == 2;
        }
        return false;
    }

    /// @notice Returns the role ID linked to a given account.
    ///
    /// @param _account The account to check.
    ///
    /// @return The role ID linked to the given account.
    function getAccountRole(
        address _account
    ) public view returns (string memory) {
        if (accountIndex[_account] == 0) {
            return "NONE";
        }

        uint256 acctIndex = _getAccountIndex(_account);
        if (accountAccessList[acctIndex].status != 0) {
            return accountAccessList[acctIndex].role;
        } else {
            return "NONE";
        }
    }

    /// @notice Returns the account status for a given account.
    ///
    /// @param _account The account to check.
    ///
    /// @return The account status for a given account.
    function getAccountStatus(address _account) public view returns (uint256) {
        if (accountIndex[_account] == 0) {
            return 0;
        }

        uint256 aIndex = _getAccountIndex(_account);
        return (accountAccessList[aIndex].status);
    }

    /// @notice Checks whether an account is an Org Admin of the provided org
    /// or of the ultimate parent organization.
    ///
    /// @param _account     The account to check.
    /// @param _orgId       The org ID to check.
    /// @param _ultParent   The master org ID.
    ///
    /// Whether the provided account is an Org Admin of the provided org or of
    /// the ultimate parent organization.
    function checkOrgAdmin(
        address _account,
        string memory _orgId,
        string memory _ultParent
    ) public view returns (bool) {
        // Check if the account role is a Network Admin. If yes, return success.
        if (
            keccak256(abi.encode(getAccountRole(_account))) ==
            keccak256(abi.encode(adminRole))
        ) {
            // Check of the org ID is Network Admin org. If yes, then return true.
            uint256 id = _getAccountIndex(_account);
            return ((keccak256(abi.encode(accountAccessList[id].orgId)) ==
                keccak256(abi.encode(_orgId))) ||
                (keccak256(abi.encode(accountAccessList[id].orgId)) ==
                    keccak256(abi.encode(_ultParent))));
        }
        return ((orgAdminIndex[keccak256(abi.encode(_orgId))] == _account) ||
            (orgAdminIndex[keccak256(abi.encode(_ultParent))] == _account));
    }

    /// @notice Returns the index for a given account.
    ///
    /// @param _account The account for which the index is retrieved.
    ///
    /// @return The account index.
    function _getAccountIndex(
        address _account
    ) internal view returns (uint256) {
        return accountIndex[_account] - 1;
    }

    /// @notice Sets the account role to the passed role ID and sets the status
    ///
    /// @param _account The account for which the role is set.
    /// @param _orgId   The org ID.
    /// @param _status  The status to be set.
    /// @param _oAdmin  Whether the account is an Org Admin.
    function _setAccountRole(
        address _account,
        string memory _orgId,
        string memory _roleId,
        uint256 _status,
        bool _oAdmin
    ) internal onlyImplementation {
        // Check if account already exists
        uint256 aIndex = _getAccountIndex(_account);
        if (accountIndex[_account] != 0) {
            accountAccessList[aIndex].role = _roleId;
            accountAccessList[aIndex].status = _status;
            accountAccessList[aIndex].orgAdmin = _oAdmin;
        } else {
            numAccounts++;
            accountIndex[_account] = numAccounts;
            accountAccessList.push(
                AccountAccessDetails(
                    _account,
                    _orgId,
                    _roleId,
                    _status,
                    _oAdmin
                )
            );
        }
        emit AccountAccessModified(_account, _orgId, _roleId, _oAdmin, _status);
    }
}
