pragma solidity ^0.5.3;

import "./PermissionsUpgradable.sol";

/// @title RoleManager
///
/// @notice This contract holds the implementation logic for all role management
/// functionality. This can be called only by the Implementation contract.
///
/// There are a number of view functions exposed as public and can be called
/// directly. These are invoked by Quorum for populating permissions data in
/// cache.
contract RoleManager {
    PermissionsUpgradable private permUpgradable;

    struct RoleDetails {
        string roleId;
        string orgId;
        uint256 baseAccess;
        bool isVoter;
        bool isAdmin;
        bool active;
    }

    RoleDetails[] private roleList;
    mapping(bytes32 => uint256) private roleIndex;
    uint256 private numberOfRoles;

    event RoleCreated(
        string _roleId,
        string _orgId,
        uint256 _baseAccess,
        bool _isVoter,
        bool _isAdmin
    );
    event RoleRevoked(string _roleId, string _orgId);

    /// @notice Confirms that the caller is the address of Permissions
    /// Implementation contract.
    modifier onlyImplementation() {
        require(msg.sender == permUpgradable.getPermImpl(), "invalid caller");
        _;
    }

    /// @notice Sets the Permissions Upgradable address.
    ///
    /// @param _permUpgradable The Permissions Upgradable address.
    constructor(address _permUpgradable) public {
        permUpgradable = PermissionsUpgradable(_permUpgradable);
    }

    /// @notice Adds a new role definition to an organization.
    ///
    /// @param _roleId      The unique identifier for the role being added.
    /// @param _orgId       The org ID to which the role belongs.
    /// @param _baseAccess  Can be from 0 to 7.
    /// @param _isVoter     Whether the role is a voter role.
    /// @param _isAdmin     Whether the role is an admin role.
    ///
    /// @dev Base access can have any of the following values:
    ///
    /// -   0: Read only
    /// -   1: value transfer
    /// -   2: contract deploy
    /// -   3: full access
    /// -   4: contract call
    /// -   5: value transfer and contract call
    /// -   6: value transfer and contract deploy
    /// -   7: contract call and deploy
    function addRole(
        string memory _roleId,
        string memory _orgId,
        uint256 _baseAccess,
        bool _isVoter,
        bool _isAdmin
    ) public onlyImplementation {
        require(_baseAccess < 8, "invalid access value");
        // Check if account already exists
        require(
            roleIndex[keccak256(abi.encode(_roleId, _orgId))] == 0,
            "role exists for the org"
        );
        numberOfRoles++;
        roleIndex[keccak256(abi.encode(_roleId, _orgId))] = numberOfRoles;
        roleList.push(
            RoleDetails(_roleId, _orgId, _baseAccess, _isVoter, _isAdmin, true)
        );
        emit RoleCreated(_roleId, _orgId, _baseAccess, _isVoter, _isAdmin);
    }

    /// @notice Removes an existing role definition from an organization.
    ///
    /// @param _roleId  The unique identifier for the role being removed.
    /// @param _orgId   The org ID to which the role belongs.
    function removeRole(
        string calldata _roleId,
        string calldata _orgId
    ) external onlyImplementation {
        require(
            roleIndex[keccak256(abi.encode(_roleId, _orgId))] != 0,
            "role does not exist"
        );
        uint256 rIndex = _getRoleIndex(_roleId, _orgId);
        roleList[rIndex].active = false;
        emit RoleRevoked(_roleId, _orgId);
    }

    /// @notice Checks whether the role is a voter role.
    ///
    /// @param _roleId      The unique identifier for the role being checked.
    /// @param _orgId       The org ID to which the role belongs.
    /// @param _ultParent   The master org ID.
    ///
    /// @return True if the role is a voter role, false otherwise.
    ///
    /// @dev Checks for the role's existence in the passed org and master org.
    function isVoterRole(
        string calldata _roleId,
        string calldata _orgId,
        string calldata _ultParent
    ) external view onlyImplementation returns (bool) {
        if (!(roleExists(_roleId, _orgId, _ultParent))) {
            return false;
        }
        uint256 rIndex;
        if (roleIndex[keccak256(abi.encode(_roleId, _orgId))] != 0) {
            rIndex = _getRoleIndex(_roleId, _orgId);
        } else {
            rIndex = _getRoleIndex(_roleId, _ultParent);
        }
        return (roleList[rIndex].active && roleList[rIndex].isVoter);
    }

    /// @notice Checks whether the role is an admin role.
    ///
    /// @param _roleId      The unique identifier for the role being checked.
    /// @param _orgId       The org ID to which the role belongs.
    /// @param _ultParent   The master org ID.
    ///
    /// @return True if the role is an admin role, false otherwise.
    ///
    /// @dev Checks for the role's existence in the passed org and master org.
    function isAdminRole(
        string calldata _roleId,
        string calldata _orgId,
        string calldata _ultParent
    ) external view onlyImplementation returns (bool) {
        if (!(roleExists(_roleId, _orgId, _ultParent))) {
            return false;
        }
        uint256 rIndex;
        if (roleIndex[keccak256(abi.encode(_roleId, _orgId))] != 0) {
            rIndex = _getRoleIndex(_roleId, _orgId);
        } else {
            rIndex = _getRoleIndex(_roleId, _ultParent);
        }
        return (roleList[rIndex].active && roleList[rIndex].isAdmin);
    }

    /// @notice Returns the role details for a passed role ID and org.
    ///
    /// @param _roleId  The unique identifier for the role being checked.
    /// @param _orgId   The org ID to which the role belongs.
    ///
    /// @return The role ID.
    /// @return The org ID.
    /// @return The access type.
    /// @return Whether the role is a voter role.
    /// @return Whether the role is an admin role.
    /// @return Whether the role is active.
    function getRoleDetails(
        string calldata _roleId,
        string calldata _orgId
    )
        external
        view
        returns (
            string memory roleId,
            string memory orgId,
            uint256 accessType,
            bool voter,
            bool admin,
            bool active
        )
    {
        if (!(roleExists(_roleId, _orgId, ""))) {
            return (_roleId, "", 0, false, false, false);
        }
        uint256 rIndex = _getRoleIndex(_roleId, _orgId);
        return (
            roleList[rIndex].roleId,
            roleList[rIndex].orgId,
            roleList[rIndex].baseAccess,
            roleList[rIndex].isVoter,
            roleList[rIndex].isAdmin,
            roleList[rIndex].active
        );
    }

    /// @notice Returns the role details for a passed role index.
    ///
    /// @param _rIndex The index to fetch at.
    ///
    /// @return The role ID.
    /// @return The org ID.
    /// @return The access type.
    /// @return Whether the role is a voter role.
    /// @return Whether the role is an admin role.
    /// @return Whether the role is active.
    function getRoleDetailsFromIndex(
        uint256 _rIndex
    )
        external
        view
        returns (
            string memory roleId,
            string memory orgId,
            uint256 accessType,
            bool voter,
            bool admin,
            bool active
        )
    {
        return (
            roleList[_rIndex].roleId,
            roleList[_rIndex].orgId,
            roleList[_rIndex].baseAccess,
            roleList[_rIndex].isVoter,
            roleList[_rIndex].isAdmin,
            roleList[_rIndex].active
        );
    }

    /// @notice Returns the total number of roles in the network.
    ///
    /// @return The total number of roles in the network.
    function getNumberOfRoles() external view returns (uint256) {
        return roleList.length;
    }

    /// @notice Checks whether the role exists in a given org or master org.
    ///
    /// @param _roleId      The unique identifier for the role to check.
    /// @param _orgId       The org ID to which the role belongs.
    /// @param _ultParent   The master org ID.
    ///
    /// @return True if the role exists, false otherwise.
    function roleExists(
        string memory _roleId,
        string memory _orgId,
        string memory _ultParent
    ) public view returns (bool) {
        uint256 id;
        if (roleIndex[keccak256(abi.encode(_roleId, _orgId))] != 0) {
            id = _getRoleIndex(_roleId, _orgId);
            return roleList[id].active;
        } else if (roleIndex[keccak256(abi.encode(_roleId, _ultParent))] != 0) {
            id = _getRoleIndex(_roleId, _ultParent);
            return roleList[id].active;
        }
        return false;
    }

    /// @notice Returns a role's access.
    ///
    /// @param _roleId      The unique identifier for the role to check.
    /// @param _orgId       The org ID to which the role belongs.
    /// @param _ultParent   The master org ID.
    ///
    /// @return The role's access.
    function roleAccess(
        string memory _roleId,
        string memory _orgId,
        string memory _ultParent
    ) public view returns (uint256) {
        uint256 id;
        if (roleIndex[keccak256(abi.encode(_roleId, _orgId))] != 0) {
            id = _getRoleIndex(_roleId, _orgId);
            return roleList[id].baseAccess;
        } else if (roleIndex[keccak256(abi.encode(_roleId, _ultParent))] != 0) {
            id = _getRoleIndex(_roleId, _ultParent);
            return roleList[id].baseAccess;
        }
        return 0;
    }

    /// @notice Returns whether a given transaction is allowed.
    ///
    /// @param _roleId      The unique identifier for the role to check.
    /// @param _orgId       The org ID to which the role belongs.
    /// @param _ultParent   The master org ID.
    /// @param _typeOfTxn   The type of transaction to check.
    ///
    /// @return True if the transaction is allowed, false otherwise.
    function transactionAllowed(
        string calldata _roleId,
        string calldata _orgId,
        string calldata _ultParent,
        uint256 _typeOfTxn
    ) external view returns (bool) {
        uint256 access = roleAccess(_roleId, _orgId, _ultParent);

        if (access == 3) {
            return true;
        }
        if (_typeOfTxn == 1 && (access == 1 || access == 5 || access == 6)) {
            return true;
        }
        if (_typeOfTxn == 2 && (access == 2 || access == 6 || access == 7)) {
            return true;
        }
        if (_typeOfTxn == 3 && (access == 4 || access == 5 || access == 7)) {
            return true;
        }

        return false;
    }

    /// @notice Returns the role's index based on role ID and org ID.
    ///
    /// @param _roleId      The unique identifier for the role to check.
    /// @param _orgId       The org ID to which the role belongs.
    ///
    /// @return The role's index.
    function _getRoleIndex(
        string memory _roleId,
        string memory _orgId
    ) internal view returns (uint256) {
        return roleIndex[keccak256(abi.encode(_roleId, _orgId))] - 1;
    }
}
