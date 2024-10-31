pragma solidity ^0.5.3;

import "./PermissionsImplementation.sol";
import "./PermissionsUpgradable.sol";

/// @title PermissionsInterface
///
/// @notice This contract is the interface for the Permissions Implementation
/// contract. For any call, it forwards the call to the Permissions
/// Implementation contract.
contract PermissionsInterface {
    PermissionsImplementation private permImplementation;
    PermissionsUpgradable private permUpgradable;
    address private permImplUpgradeable;

    /// @notice  Sets the PermissionsUpgradable address.
    ///
    /// @param _permImplUpgradeable The PermissionsUpgradable contract address.
    constructor(address _permImplUpgradeable) public {
        permImplUpgradeable = _permImplUpgradeable;
    }

    /// @notice Confirms that the caller is the address of upgradable contract.
    modifier onlyUpgradeable() {
        require(msg.sender == permImplUpgradeable, "invalid caller");
        _;
    }

    /// @notice Interface for setting the permissions policy in the Implementation
    /// contract.
    ///
    /// @param _nwAdminOrg  Network admin organization ID
    /// @param _nwAdminRole Default network admin role ID
    /// @param _oAdminRole  Default organization admin role ID
    function setPolicy(
        string calldata _nwAdminOrg,
        string calldata _nwAdminRole,
        string calldata _oAdminRole
    ) external {
        permImplementation.setPolicy(_nwAdminOrg, _nwAdminRole, _oAdminRole);
    }

    /// @notice Interface to initializes the breadth and depth values for sub
    /// organization management.
    ///
    /// @param _breadth Controls the number of sub orgs a parent org can have.
    /// @param _depth   Controls the depth of nesting allowed for sub orgs.
    function init(uint256 _breadth, uint256 _depth) external {
        permImplementation.init(_breadth, _depth);
    }

    /// @notice Interface to add new node to an admin organization.
    ///
    /// @param _enodeId     The enode ID of the node to be added.
    /// @param _ip          The IP of the node.
    /// @param _port        The TCP port of the node.
    /// @param _raftport    The raft port of the node.
    function addAdminNode(
        string memory _enodeId,
        string memory _ip,
        uint16 _port,
        uint16 _raftport
    ) public {
        permImplementation.addAdminNode(_enodeId, _ip, _port, _raftport);
    }

    /// @notice Interface to add accounts to an admin organization.
    ///
    /// @param _acct The account address to be added.
    function addAdminAccount(address _acct) external {
        permImplementation.addAdminAccount(_acct);
    }

    /// @notice Interface to update network boot up status.
    ///
    /// @return bool True or false.
    function updateNetworkBootStatus() external returns (bool) {
        return permImplementation.updateNetworkBootStatus();
    }

    /// @notice Interface to fetch network boot status.
    ///
    /// @return The network boot status.
    function getNetworkBootStatus() external view returns (bool) {
        return permImplementation.getNetworkBootStatus();
    }

    /// @notice Interface to add a new organization to the network.
    ///
    /// @param _orgId       The unique organization ID.
    /// @param _enodeId     The enode ID linked to the organization.
    /// @param _ip          The IP of the node.
    /// @param _port        The TCP port of the node.
    /// @param _raftport    The raft port of the node.
    /// @param _account     The account ID. Will have the org admin privileges.
    function addOrg(
        string memory _orgId,
        string memory _enodeId,
        string memory _ip,
        uint16 _port,
        uint16 _raftport,
        address _account
    ) public {
        permImplementation.addOrg(
            _orgId,
            _enodeId,
            _ip,
            _port,
            _raftport,
            _account,
            msg.sender
        );
    }

    /// @notice Interface to approve a newly added organization.
    ///
    /// @param _orgId       The unique organization ID.
    /// @param _enodeId     The enode ID linked to the organization.
    /// @param _ip          The IP of the node.
    /// @param _port        The TCP port of the node.
    /// @param _raftport    The raft port of the node.
    /// @param _account     The account ID. Will have the org admin privileges.
    function approveOrg(
        string memory _orgId,
        string memory _enodeId,
        string memory _ip,
        uint16 _port,
        uint16 _raftport,
        address _account
    ) public {
        permImplementation.approveOrg(
            _orgId,
            _enodeId,
            _ip,
            _port,
            _raftport,
            _account,
            msg.sender
        );
    }

    /// @notice Interface to add sub org under an org.
    ///
    /// @param _pOrgId      The parent org ID under which the sub org is being added.
    /// @param _orgId       The unique ID for the sub organization.
    /// @param _enodeId     The enode ID linked to the sub organization.
    /// @param _ip          The IP of the node.
    /// @param _port        The TCP  port of the node.
    /// @param _raftport    The raft port of the node.
    function addSubOrg(
        string memory _pOrgId,
        string memory _orgId,
        string memory _enodeId,
        string memory _ip,
        uint16 _port,
        uint16 _raftport
    ) public {
        permImplementation.addSubOrg(
            _pOrgId,
            _orgId,
            _enodeId,
            _ip,
            _port,
            _raftport,
            msg.sender
        );
    }

    /// @notice Interface to update the org status.
    ///
    /// @param _orgId   The unique ID of the organization.
    /// @param _action  The action to perform.
    ///
    /// @dev Available actiosn:
    ///
    /// -   1: Suspends an org;
    /// -   2: Revokes the suspension of an org.
    function updateOrgStatus(string calldata _orgId, uint256 _action) external {
        permImplementation.updateOrgStatus(_orgId, _action, msg.sender);
    }

    /// @notice Interface to approve org status change.
    ///
    /// @param _orgId   The unique ID of the organization.
    /// @param _action  The action to perform.
    ///
    /// @dev Available actiosn:
    ///
    /// -   1: Suspends an org;
    /// -   2: Revokes the suspension of an org.
    function approveOrgStatus(
        string calldata _orgId,
        uint256 _action
    ) external {
        permImplementation.approveOrgStatus(_orgId, _action, msg.sender);
    }

    /// @notice Interface to add a new role definition to an organization.
    ///
    /// @param _roleId  The unique ID for the role.
    /// @param _orgId   The unique ID of the organization to which the role belongs.
    /// @param _access  The account access type for the role.
    /// @param _voter   Whether role is a voter role or not.
    /// @param _admin   Whether the role is an admin role.
    ///
    /// @dev Account access type can have of the following four values:
    ///
    /// -   0: Read only
    /// -   1: Transact access
    /// -   2: Contract deployment access. Can transact as well
    /// -   3: Full access
    function addNewRole(
        string calldata _roleId,
        string calldata _orgId,
        uint256 _access,
        bool _voter,
        bool _admin
    ) external {
        permImplementation.addNewRole(
            _roleId,
            _orgId,
            _access,
            _voter,
            _admin,
            msg.sender
        );
    }

    /// @notice Interface to remove a role definition from an organization.
    ///
    /// @param _roleId  The unique ID for the role.
    /// @param _orgId   The unique ID of the organization to which the role belongs.
    function removeRole(
        string calldata _roleId,
        string calldata _orgId
    ) external {
        permImplementation.removeRole(_roleId, _orgId, msg.sender);
    }

    /// @notice Interface to assign network admin/org admin role to an account.
    ///
    /// @param _orgId   The unique ID of the organization to which the account belongs.
    /// @param _account The account ID.
    /// @param _roleId  The role ID to be assigned to the account.
    ///
    /// @dev This can be executed by network admin accounts only.
    function assignAdminRole(
        string calldata _orgId,
        address _account,
        string calldata _roleId
    ) external {
        permImplementation.assignAdminRole(
            _orgId,
            _account,
            _roleId,
            msg.sender
        );
    }

    /// @notice Interface to approve network admin/org admin role assigment.
    ///
    /// @param _orgId   The unique ID of the organization to which the account belongs.
    /// @param _account The account ID.
    ///
    /// @dev This can be executed by network admin accounts only.
    function approveAdminRole(
        string calldata _orgId,
        address _account
    ) external {
        permImplementation.approveAdminRole(_orgId, _account, msg.sender);
    }

    /// @notice Interface to update account status.
    ///
    /// @param _orgId   The unique ID of the organization to which the account belongs.
    /// @param _account The account ID.
    /// @param _action  The action to perform.
    ///
    /// @dev This can be executed by network admin accounts only.
    ///
    /// Available actions:
    ///
    /// -   1: Suspending;
    /// -   2: Activating back;
    /// -   3: Blacklisting.
    function updateAccountStatus(
        string calldata _orgId,
        address _account,
        uint256 _action
    ) external {
        permImplementation.updateAccountStatus(
            _orgId,
            _account,
            _action,
            msg.sender
        );
    }

    /// @notice Interface to add a new node to the organization
    ///
    /// @param _orgId       The unique ID of the organization to which the account belongs.
    /// @param _enodeId     The enode ID being added to the org.
    /// @param _ip          The IP of the node.
    /// @param _port        The TCP port of the node.
    /// @param _raftport    The raft port of the node.
    function addNode(
        string memory _orgId,
        string memory _enodeId,
        string memory _ip,
        uint16 _port,
        uint16 _raftport
    ) public {
        permImplementation.addNode(
            _orgId,
            _enodeId,
            _ip,
            _port,
            _raftport,
            msg.sender
        );
    }

    /// @notice Interface to update node status.
    ///
    /// @param _orgId       The unique ID of the organization to which the account belongs.
    /// @param _enodeId     The enode ID being added to the org.
    /// @param _ip          The IP of the node.
    /// @param _port        The TCP port of the node.
    /// @param _raftport    The raft port of the node.
    /// @param _action      The action to perform.
    ///
    /// @dev Available actions:
    ///
    /// -   1: Deactivate;
    /// -   2: Activate back;
    /// -   3: Blacklist the node.
    function updateNodeStatus(
        string memory _orgId,
        string memory _enodeId,
        string memory _ip,
        uint16 _port,
        uint16 _raftport,
        uint256 _action
    ) public {
        permImplementation.updateNodeStatus(
            _orgId,
            _enodeId,
            _ip,
            _port,
            _raftport,
            _action,
            msg.sender
        );
    }

    /// @notice Interface to initiate blacklisted node recovery.
    ///
    /// @param _orgId       The unique ID of the organization to which the account belongs.
    /// @param _enodeId     The enode ID being recovered.
    /// @param _ip          The IP of node.
    /// @param _port        The TCP port of the node.
    /// @param _raftport    The raft port of the node.
    function startBlacklistedNodeRecovery(
        string memory _orgId,
        string memory _enodeId,
        string memory _ip,
        uint16 _port,
        uint16 _raftport
    ) public {
        permImplementation.startBlacklistedNodeRecovery(
            _orgId,
            _enodeId,
            _ip,
            _port,
            _raftport,
            msg.sender
        );
    }

    /// @notice Interface to approve blacklisted node recovery.
    ///
    /// @param _orgId       The unique ID of the organization to which the account belongs.
    /// @param _enodeId     The enode ID being recovered.
    /// @param _ip          The IP of the node.
    /// @param _port        The TCP port of the node.
    /// @param _raftport    The raft port of the node.
    function approveBlacklistedNodeRecovery(
        string memory _orgId,
        string memory _enodeId,
        string memory _ip,
        uint16 _port,
        uint16 _raftport
    ) public {
        permImplementation.approveBlacklistedNodeRecovery(
            _orgId,
            _enodeId,
            _ip,
            _port,
            _raftport,
            msg.sender
        );
    }

    /// @notice Interface to initiate blacklisted account recovery.
    ///
    /// @param _orgId   The unique ID of the organization to which the account belongs.
    /// @param _account The account ID being recovered.
    function startBlacklistedAccountRecovery(
        string calldata _orgId,
        address _account
    ) external {
        permImplementation.startBlacklistedAccountRecovery(
            _orgId,
            _account,
            msg.sender
        );
    }

    /// @notice Interface to approve blacklisted node recovery.
    ///
    /// @param _orgId   The unique ID of the organization to which the account belongs.
    /// @param _account The account ID being recovered.
    function approveBlacklistedAccountRecovery(
        string calldata _orgId,
        address _account
    ) external {
        permImplementation.approveBlacklistedAccountRecovery(
            _orgId,
            _account,
            msg.sender
        );
    }

    /// @notice Interface to fetch details of any pending approval activities
    /// for the network admin organization.
    ///
    /// @param _orgId The unique ID of the organization.
    function getPendingOp(
        string calldata _orgId
    ) external view returns (string memory, string memory, address, uint256) {
        return permImplementation.getPendingOp(_orgId);
    }

    /// @notice Sets the Permissions Implementation contract address.
    ///
    /// @param _permImplementation The Permissions Implementation address.
    ///
    /// @dev Can only be called from the Permissions Upgradable contract.
    function setPermImplementation(
        address _permImplementation
    ) external onlyUpgradeable {
        permImplementation = PermissionsImplementation(_permImplementation);
    }

    /// @notice Returns the address of the Permissions Implementation contract.
    /// @return The Permissions Implementation contract address.
    function getPermissionsImpl() external view returns (address) {
        return address(permImplementation);
    }

    /// @notice Interface to assign a role ID to the given account.
    ///
    /// @param _account The account ID
    /// @param _orgId   The organization ID to which the account belongs.
    /// @param _roleId  The role ID to be assigned to the account.
    function assignAccountRole(
        address _account,
        string calldata _orgId,
        string calldata _roleId
    ) external {
        permImplementation.assignAccountRole(
            _account,
            _orgId,
            _roleId,
            msg.sender
        );
    }

    /// @notice Interface to check if passed account is an network admin account.
    ///
    /// @param _account The account ID.
    ///
    /// @return True if the account is a network admin, false otherwise.
    function isNetworkAdmin(address _account) external view returns (bool) {
        return permImplementation.isNetworkAdmin(_account);
    }

    /// @notice Interface to check if passed account is an org admin account.
    ///
    /// @param _account The account ID.
    /// @param _orgId   The organization ID.
    ///
    /// @return True if the account is an org admin, false otherwise.
    function isOrgAdmin(
        address _account,
        string calldata _orgId
    ) external view returns (bool) {
        return permImplementation.isOrgAdmin(_account, _orgId);
    }

    /// @notice Interface to validate the account for an access change operation.
    ///
    /// @param _account The account ID.
    /// @param _orgId   The organization ID.
    ///
    /// @return True if the account is valid, false otherwise.
    function validateAccount(
        address _account,
        string calldata _orgId
    ) external view returns (bool) {
        return permImplementation.validateAccount(_account, _orgId);
    }

    /// @notice Checks whether the node is allowed to connect.
    ///
    /// @param _enodeId The enode ID.
    /// @param _ip      The IP of the node.
    /// @param _port    The TCP port of the node.
    ///
    /// @return True if the node is allowed to connect, false otherwise.
    function connectionAllowed(
        string calldata _enodeId,
        string calldata _ip,
        uint16 _port
    ) external view returns (bool) {
        return permImplementation.connectionAllowed(_enodeId, _ip, _port);
    }

    /// @notice Checks whether the account is allowed to transact.
    ///
    /// @param _sender      The source account.
    /// @param _target      The target account.
    /// @param _value       The value being transferred.
    /// @param _gasPrice    The gas price.
    /// @param _gasLimit    The gas limit.
    /// @param _payload     The payload for transactions on contracts.
    ///
    /// @return True if the account is allowed to transact, false otherwise.
    function transactionAllowed(
        address _sender,
        address _target,
        uint256 _value,
        uint256 _gasPrice,
        uint256 _gasLimit,
        bytes calldata _payload
    ) external view returns (bool) {
        return
            permImplementation.transactionAllowed(
                _sender,
                _target,
                _value,
                _gasPrice,
                _gasLimit,
                _payload
            );
    }
}
