pragma solidity ^0.5.3;

import "./PermissionsUpgradable.sol";

/// @title OrgManager
///
/// @notice This contract holds the implementation logic for all organization
/// management functionality. This contract can only be called into by the
/// `PermissionsImplementation` contract.
///
/// There are a number of view functions exposed as public and can be called
/// directly. These are invoked by Quorum for populating permissions data in cache.
///
/// @dev The status of the organization is denoted by a set of integer values.
/// These are as below:
///
/// -   0: Not in list
/// -   1: Org proposed for approval by network admins
/// -   2: Org iscl Approved status
/// -   3: Org proposed for suspension and pending approval by network admins
/// -   4: Org in Suspended
///
/// Once the node is blacklisted no further activity on the node is possible.
contract OrgManager {
    string private adminOrgId;
    PermissionsUpgradable private permUpgradable;
    // Indicates whether the network boot has happened.
    bool private networkBoot = false;

    // Variables which control the breadth and depth of the sub org tree.
    uint private DEPTH_LIMIT = 4;
    uint private BREADTH_LIMIT = 4;

    struct OrgDetails {
        string orgId;
        uint status;
        string parentId;
        string fullOrgId;
        string ultParent;
        uint pindex;
        uint level;
        uint[] subOrgIndexList;
    }

    OrgDetails[] private orgList;
    mapping(bytes32 => uint) private OrgIndex;
    uint private orgNum = 0;

    // Events related to Master Org add.
    event OrgApproved(
        string _orgId,
        string _porgId,
        string _ultParent,
        uint _level,
        uint _status
    );

    event OrgPendingApproval(
        string _orgId,
        string _porgId,
        string _ultParent,
        uint _level,
        uint _status
    );

    event OrgSuspended(
        string _orgId,
        string _porgId,
        string _ultParent,
        uint _level
    );

    event OrgSuspensionRevoked(
        string _orgId,
        string _porgId,
        string _ultParent,
        uint _level
    );

    /// @notice Confirms that the caller is the Permissions Implementation contract.
    modifier onlyImplementation() {
        require(msg.sender == permUpgradable.getPermImpl(), "invalid caller");
        _;
    }

    /// @notice Checks that the org ID does not exist.
    ///
    /// @param _orgId The org ID to check.
    modifier orgDoesNotExist(string memory _orgId) {
        require(checkOrgExists(_orgId) == false, "org exists");
        _;
    }

    /// @notice Checks that the org ID does exist.
    ///
    /// @param _orgId The org ID to check.
    modifier orgExists(string memory _orgId) {
        require(checkOrgExists(_orgId) == true, "org does not exist");
        _;
    }

    /// @notice  Sets the PermissionsUpgradable address.
    ///
    /// @param _permUpgradable The PermissionsUpgradable contract address.
    constructor(address _permUpgradable) public {
        permUpgradable = PermissionsUpgradable(_permUpgradable);
    }

    /// @notice Called at the time of network initialization. Sets the depth and
    /// breadth for sub orgs creation. Creates the default Network Admin org as
    /// per the config file.
    ///
    /// @param _orgId   The org ID.
    /// @param _breadth The bredth to set.
    /// @param _depth   The depth to set.
    function setUpOrg(
        string calldata _orgId,
        uint256 _breadth,
        uint256 _depth
    ) external onlyImplementation {
        _addNewOrg("", _orgId, 1, 2);
        DEPTH_LIMIT = _depth;
        BREADTH_LIMIT = _breadth;
    }

    /// @notice Adds a new master org to the network.
    ///
    /// @param _orgId Unique org ID to add.
    ///
    /// @dev The org will be added if it does exist.
    function addOrg(
        string calldata _orgId
    ) external onlyImplementation orgDoesNotExist(_orgId) {
        _addNewOrg("", _orgId, 1, 1);
    }

    /// @notice Adds a new sub org under a parent org.
    ///
    /// @param _pOrgId  Unique parent org ID.
    /// @param _orgId   Unique org ID to add.
    ///
    /// @dev The org will be added if it does exist.
    function addSubOrg(
        string calldata _pOrgId,
        string calldata _orgId
    )
        external
        onlyImplementation
        orgDoesNotExist(string(abi.encodePacked(_pOrgId, ".", _orgId)))
    {
        _addNewOrg(_pOrgId, _orgId, 2, 2);
    }

    /// @notice Updates the status of a master org.
    ///
    /// @param _orgId   The unique org ID to be updated.
    /// @param _action  The action being performed.
    ///
    /// @dev Status cannot be updated for sub orgs.
    ///
    /// This function can be called for the following actions:
    ///
    /// -   1: To suspend an org
    /// -   2: To reactivate the org
    function updateOrg(
        string calldata _orgId,
        uint256 _action
    ) external onlyImplementation orgExists(_orgId) returns (uint256) {
        require(
            (_action == 1 || _action == 2),
            "invalid action. operation not allowed"
        );
        uint256 id = _getOrgIndex(_orgId);
        require(
            orgList[id].level == 1,
            "not a master org. operation not allowed"
        );

        uint256 reqStatus;
        uint256 pendingOp;
        if (_action == 1) {
            reqStatus = 2;
            pendingOp = 2;
        } else if (_action == 2) {
            reqStatus = 4;
            pendingOp = 3;
        }
        require(
            checkOrgStatus(_orgId, reqStatus) == true,
            "org status does not allow the operation"
        );
        if (_action == 1) {
            _suspendOrg(_orgId);
        } else {
            _revokeOrgSuspension(_orgId);
        }
        return pendingOp;
    }

    /// @notice Approves an org status change for master orgs.
    ///
    /// @param _orgId   The unique org ID.
    /// @param _action  The approval action.
    ///
    /// @dev Status cannot be updated for sub orgs.
    ///
    /// This function can be called for the following actions:
    ///
    /// -   1: To suspend an org
    /// -   2: To reactivate the org
    function approveOrgStatusUpdate(
        string calldata _orgId,
        uint256 _action
    ) external onlyImplementation orgExists(_orgId) {
        if (_action == 1) {
            _approveOrgSuspension(_orgId);
        } else {
            _approveOrgRevokeSuspension(_orgId);
        }
    }

    /// @notice Approves an org.
    ///
    /// @param _orgId unique org ID.
    function approveOrg(string calldata _orgId) external onlyImplementation {
        require(checkOrgStatus(_orgId, 1) == true, "nothing to approve");
        uint256 id = _getOrgIndex(_orgId);
        orgList[id].status = 2;
        emit OrgApproved(
            orgList[id].orgId,
            orgList[id].parentId,
            orgList[id].ultParent,
            orgList[id].level,
            2
        );
    }

    /// @notice Returns org info for a given org index.
    ///
    /// @param _orgIndex The org index.
    ///
    /// @return The org ID.
    /// @return The parent org ID.
    /// @return The ultimate parent ID.
    /// @return The level in the org tree.
    /// @return The org status.
    function getOrgInfo(
        uint256 _orgIndex
    )
        external
        view
        returns (string memory, string memory, string memory, uint256, uint256)
    {
        return (
            orgList[_orgIndex].orgId,
            orgList[_orgIndex].parentId,
            orgList[_orgIndex].ultParent,
            orgList[_orgIndex].level,
            orgList[_orgIndex].status
        );
    }

    /// @notice Returns org info for a given org ID.
    ///
    /// @param _orgId org id
    ///
    /// @return The org ID.
    /// @return The parent org ID.
    /// @return The ultimate parent ID.
    /// @return The level in the org tree.
    /// @return The org status.
    function getOrgDetails(
        string calldata _orgId
    )
        external
        view
        returns (string memory, string memory, string memory, uint256, uint256)
    {
        if (!checkOrgExists(_orgId)) {
            return (_orgId, "", "", 0, 0);
        }
        uint256 _orgIndex = _getOrgIndex(_orgId);
        return (
            orgList[_orgIndex].orgId,
            orgList[_orgIndex].parentId,
            orgList[_orgIndex].ultParent,
            orgList[_orgIndex].level,
            orgList[_orgIndex].status
        );
    }

    /// @notice Returns the array of sub org indexes for the given org.
    ///
    /// @param _orgId The org ID.
    ///
    /// @return An array of sub org indexes.
    function getSubOrgIndexes(
        string calldata _orgId
    ) external view returns (uint[] memory) {
        require(checkOrgExists(_orgId) == true, "org does not exist");
        uint256 _orgIndex = _getOrgIndex(_orgId);
        return (orgList[_orgIndex].subOrgIndexList);
    }

    /// @notice Returns the master org ID for the given org or sub org.
    ///
    /// @param _orgId The org ID.
    ///
    /// @return The master org ID.
    function getUltimateParent(
        string calldata _orgId
    ) external view onlyImplementation returns (string memory) {
        return orgList[_getOrgIndex(_orgId)].ultParent;
    }

    /// @notice Returns the total number of orgs in the network.
    ///
    /// @return The total number of orgs in the network.
    function getNumberOfOrgs() public view returns (uint256) {
        return orgList.length;
    }

    /// @notice Confirms that an org status is same as a given status.
    ///
    /// @param _orgId       The org ID.
    /// @param _orgStatus   The org status to compare against.
    ///
    /// @return True if the org ID status matches the given status, false
    /// otherwise.
    function checkOrgStatus(
        string memory _orgId,
        uint256 _orgStatus
    ) public view returns (bool) {
        if (OrgIndex[keccak256(abi.encodePacked(_orgId))] == 0) {
            return false;
        }
        uint256 id = _getOrgIndex(_orgId);
        return ((OrgIndex[keccak256(abi.encodePacked(_orgId))] != 0) &&
            orgList[id].status == _orgStatus);
    }

    /// @notice Confirms that an org is either active or pending suspension.
    ///
    /// @param _orgId The org ID to check.
    ///
    /// @return True if the org is either active or pending suspension, false
    /// otherwise.
    function checkOrgActive(string memory _orgId) public view returns (bool) {
        if (OrgIndex[keccak256(abi.encodePacked(_orgId))] != 0) {
            uint256 id = _getOrgIndex(_orgId);
            if (orgList[id].status == 2 || orgList[id].status == 3) {
                uint256 uid = _getOrgIndex(orgList[id].ultParent);
                if (orgList[uid].status == 2 || orgList[uid].status == 3) {
                    return true;
                }
            }
        }
        return false;
    }

    /// @notice Confirms if the org exists in the network.
    ///
    /// @param _orgId The org ID to check.
    ///
    /// @return True if the org exists, false otherwise.
    function checkOrgExists(string memory _orgId) public view returns (bool) {
        return (!(OrgIndex[keccak256(abi.encodePacked(_orgId))] == 0));
    }

    /// @notice Updates the org status to suspended.
    ///
    /// @param _orgId The org ID to update.
    function _suspendOrg(string memory _orgId) internal {
        require(
            checkOrgStatus(_orgId, 2) == true,
            "org not in approved status. operation cannot be done"
        );
        uint256 id = _getOrgIndex(_orgId);
        orgList[id].status = 3;
        emit OrgPendingApproval(
            orgList[id].orgId,
            orgList[id].parentId,
            orgList[id].ultParent,
            orgList[id].level,
            3
        );
    }

    /// @notice Revokes the suspension of an org.
    ///
    /// @param _orgId The org ID.
    function _revokeOrgSuspension(string memory _orgId) internal {
        require(
            checkOrgStatus(_orgId, 4) == true,
            "org not in suspended state"
        );
        uint256 id = _getOrgIndex(_orgId);
        orgList[id].status = 5;
        emit OrgPendingApproval(
            orgList[id].orgId,
            orgList[id].parentId,
            orgList[id].ultParent,
            orgList[id].level,
            5
        );
    }

    /// @notice Approves an org suspension activity.
    ///
    /// @param _orgId The org ID.
    function _approveOrgSuspension(string memory _orgId) internal {
        require(checkOrgStatus(_orgId, 3) == true, "nothing to approve");
        uint256 id = _getOrgIndex(_orgId);
        orgList[id].status = 4;
        emit OrgSuspended(
            orgList[id].orgId,
            orgList[id].parentId,
            orgList[id].ultParent,
            orgList[id].level
        );
    }

    /// @notice Approves revoking an org suspension.
    ///
    /// @param _orgId The org ID.
    function _approveOrgRevokeSuspension(string memory _orgId) internal {
        require(checkOrgStatus(_orgId, 5) == true, "nothing to approve");
        uint256 id = _getOrgIndex(_orgId);
        orgList[id].status = 2;
        emit OrgSuspensionRevoked(
            orgList[id].orgId,
            orgList[id].parentId,
            orgList[id].ultParent,
            orgList[id].level
        );
    }

    /// @notice Adds a new organization.
    ///
    /// @param _pOrgId  The parent org ID.
    /// @param _orgId   The org ID.
    /// @param _level   The level in org hierarchy.
    /// @param _status  The status of the org.
    function _addNewOrg(
        string memory _pOrgId,
        string memory _orgId,
        uint256 _level,
        uint _status
    ) internal {
        bytes32 pid = "";
        bytes32 oid = "";
        uint256 parentIndex = 0;

        if (_level == 1) {
            //root
            oid = keccak256(abi.encodePacked(_orgId));
        } else {
            pid = keccak256(abi.encodePacked(_pOrgId));
            oid = keccak256(abi.encodePacked(_pOrgId, ".", _orgId));
        }
        orgNum++;
        OrgIndex[oid] = orgNum;
        uint256 id = orgList.length++;
        if (_level == 1) {
            orgList[id].level = _level;
            orgList[id].pindex = 0;
            orgList[id].fullOrgId = _orgId;
            orgList[id].ultParent = _orgId;
        } else {
            parentIndex = OrgIndex[pid] - 1;

            require(
                orgList[parentIndex].subOrgIndexList.length < BREADTH_LIMIT,
                "breadth level exceeded"
            );
            require(
                orgList[parentIndex].level < DEPTH_LIMIT,
                "depth level exceeded"
            );

            orgList[id].level = orgList[parentIndex].level + 1;
            orgList[id].pindex = parentIndex;
            orgList[id].ultParent = orgList[parentIndex].ultParent;
            uint256 subOrgId = orgList[parentIndex].subOrgIndexList.length++;
            orgList[parentIndex].subOrgIndexList[subOrgId] = id;
            orgList[id].fullOrgId = string(
                abi.encodePacked(_pOrgId, ".", _orgId)
            );
        }
        orgList[id].orgId = _orgId;
        orgList[id].parentId = _pOrgId;
        orgList[id].status = _status;
        if (_status == 1) {
            emit OrgPendingApproval(
                orgList[id].orgId,
                orgList[id].parentId,
                orgList[id].ultParent,
                orgList[id].level,
                1
            );
        } else {
            emit OrgApproved(
                orgList[id].orgId,
                orgList[id].parentId,
                orgList[id].ultParent,
                orgList[id].level,
                2
            );
        }
    }

    /// @notice Returns the org index from the org list for the given org.
    /// @return The org index.
    function _getOrgIndex(string memory _orgId) private view returns (uint) {
        return OrgIndex[keccak256(abi.encodePacked(_orgId))] - 1;
    }
}
