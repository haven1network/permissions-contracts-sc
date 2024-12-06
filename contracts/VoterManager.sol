pragma solidity ^0.5.3;

import "./PermissionsUpgradable.sol";

///  @title VoterManager
///
/// @notice This contract holds the implementation logic for all account voter
/// and voting functionality.
/// This contract can only be called by the Permissions Implementation
/// contract.
///
/// There are a number of view functions exposed as public and can be called
/// directly. These functions are invoked by Quorum for populating permissions
/// data in cache.
///
/// @dev Each voting record has an attribute operation type (opType) which
/// denotes the activity type that is pending approval. It can have the following
/// values:
/// -   0: None - indicates no pending records for the org
/// -   1: New org add activity
/// -   2: Org suspension activity
/// -   3: Revoke of org suspension
/// -   4: Assigning admin role for a new account
/// -   5: Blacklisted node recovery
/// -   6: Blacklisted account recovery
contract VoterManager {
    PermissionsUpgradable private permUpgradable;
    struct PendingOpDetails {
        string orgId;
        string enodeId;
        address account;
        uint256 opType;
    }

    struct Voter {
        address vAccount;
        bool active;
    }

    struct OrgVoterDetails {
        string orgId;
        uint256 voterCount;
        uint256 validVoterCount;
        uint256 voteCount;
        PendingOpDetails pendingOp;
        Voter[] voterList;
        mapping(address => uint256) voterIndex;
        mapping(uint256 => mapping(address => bool)) votingStatus;
    }

    OrgVoterDetails[] private orgVoterList;
    mapping(bytes32 => uint256) private VoterOrgIndex;
    uint256 private orgNum = 0;

    // events related to managing voting accounts for the org
    event VoterAdded(string _orgId, address _vAccount);
    event VoterDeleted(string _orgId, address _vAccount);

    event VotingItemAdded(string _orgId);
    event VoteProcessed(string _orgId);

    /// @notice Confirms that the caller is the address of the Permissions
    /// Implementation contract.
    modifier onlyImplementation() {
        require(msg.sender == permUpgradable.getPermImpl(), "invalid caller");
        _;
    }

    /// @notice Checks whether an account has a valid voter record and belongs
    /// to the provided org.
    ///
    /// @param _orgId       The org ID
    /// @param _vAccount    The voter account.
    modifier voterExists(string memory _orgId, address _vAccount) {
        require(
            _checkVoterExists(_orgId, _vAccount) == true,
            "must be a voter"
        );
        _;
    }

    /// @notice Sets the Permissions Upgradable contract address.
    ///
    /// @param _permUpgradable The PermissionsUpgradable contract address.
    constructor(address _permUpgradable) public {
        permUpgradable = PermissionsUpgradable(_permUpgradable);
    }

    /// @notice Adds a new voter account to the organization.
    ///
    /// @param _orgId       The org ID.
    /// @param _vAccount    The voter account.
    ///
    /// @dev Voter capability is currently enabled for network level activities
    /// only. Voting is not available for org related activities.
    function addVoter(
        string calldata _orgId,
        address _vAccount
    ) external onlyImplementation {
        // check if the org exists
        if (VoterOrgIndex[keccak256(abi.encode(_orgId))] == 0) {
            orgNum++;
            VoterOrgIndex[keccak256(abi.encode(_orgId))] = orgNum;
            uint256 id = orgVoterList.length++;
            orgVoterList[id].orgId = _orgId;
            orgVoterList[id].voterCount = 1;
            orgVoterList[id].validVoterCount = 1;
            orgVoterList[id].voteCount = 0;
            orgVoterList[id].pendingOp.orgId = "";
            orgVoterList[id].pendingOp.enodeId = "";
            orgVoterList[id].pendingOp.account = address(0);
            orgVoterList[id].pendingOp.opType = 0;
            orgVoterList[id].voterIndex[_vAccount] = orgVoterList[id]
                .voterCount;
            orgVoterList[id].voterList.push(Voter(_vAccount, true));
        } else {
            uint256 id = _getVoterOrgIndex(_orgId);
            // check if the voter is already present in the list
            if (orgVoterList[id].voterIndex[_vAccount] == 0) {
                orgVoterList[id].voterCount++;
                orgVoterList[id].voterIndex[_vAccount] = orgVoterList[id]
                    .voterCount;
                orgVoterList[id].voterList.push(Voter(_vAccount, true));
                orgVoterList[id].validVoterCount++;
            } else {
                uint256 vid = _getVoterIndex(_orgId, _vAccount);
                require(
                    orgVoterList[id].voterList[vid].active != true,
                    "already a voter"
                );
                orgVoterList[id].voterList[vid].active = true;
                orgVoterList[id].validVoterCount++;
            }
        }
        emit VoterAdded(_orgId, _vAccount);
    }

    /// @notice Deletes a voter account from the organization.
    ///
    /// @param _orgId       The org ID.
    /// @param _vAccount    The voter account.
    function deleteVoter(
        string calldata _orgId,
        address _vAccount
    ) external onlyImplementation voterExists(_orgId, _vAccount) {
        uint256 id = _getVoterOrgIndex(_orgId);
        uint256 vId = _getVoterIndex(_orgId, _vAccount);
        orgVoterList[id].validVoterCount--;
        orgVoterList[id].voterList[vId].active = false;
        emit VoterDeleted(_orgId, _vAccount);
    }

    /// @notice Adds a voting item for network admin accounts to vote on.
    ///
    /// @param _authOrg     The org ID of the authorizing org. It will be a network admin org.
    /// @param _orgId       The org ID for which the voting record is being created.
    /// @param _enodeId     The enode ID for which the voting record is being created.
    /// @param _account     The account ID for which the voting record is being created.
    /// @param _pendingOp   The operation for which voting is being done.
    function addVotingItem(
        string calldata _authOrg,
        string calldata _orgId,
        string calldata _enodeId,
        address _account,
        uint256 _pendingOp
    ) external onlyImplementation {
        // check if anything is pending approval for the org.
        // If yes another item cannot be added
        require(
            (_checkPendingOp(_authOrg, 0)),
            "items pending for approval. new item cannot be added"
        );
        uint256 id = _getVoterOrgIndex(_authOrg);
        orgVoterList[id].pendingOp.orgId = _orgId;
        orgVoterList[id].pendingOp.enodeId = _enodeId;
        orgVoterList[id].pendingOp.account = _account;
        orgVoterList[id].pendingOp.opType = _pendingOp;
        // initialize vote status for voter accounts
        for (uint256 i = 0; i < orgVoterList[id].voterList.length; i++) {
            if (orgVoterList[id].voterList[i].active) {
                orgVoterList[id].votingStatus[id][
                    orgVoterList[id].voterList[i].vAccount
                ] = false;
            }
        }
        // set vote count to zero
        orgVoterList[id].voteCount = 0;
        emit VotingItemAdded(_authOrg);
    }

    /// @notice Processes a vote of a voter account.
    ///
    /// @param _authOrg     The org ID of the authorizing org. It will be a network admin org.
    /// @param _vAccount    The account ID of the voter.
    /// @param _pendingOp   The operation which is being approved.
    ///
    /// @return True if the process was successful, false otherwise.
    function processVote(
        string calldata _authOrg,
        address _vAccount,
        uint256 _pendingOp
    )
        external
        onlyImplementation
        voterExists(_authOrg, _vAccount)
        returns (bool)
    {
        // check something if anything is pending approval
        require(
            _checkPendingOp(_authOrg, _pendingOp) == true,
            "nothing to approve"
        );
        uint256 id = _getVoterOrgIndex(_authOrg);
        // check if vote is already processed
        require(
            orgVoterList[id].votingStatus[id][_vAccount] != true,
            "cannot double vote"
        );
        orgVoterList[id].voteCount++;
        orgVoterList[id].votingStatus[id][_vAccount] = true;
        emit VoteProcessed(_authOrg);
        if (orgVoterList[id].voteCount > orgVoterList[id].validVoterCount / 2) {
            // majority achieved, clean up pending op
            orgVoterList[id].pendingOp.orgId = "";
            orgVoterList[id].pendingOp.enodeId = "";
            orgVoterList[id].pendingOp.account = address(0);
            orgVoterList[id].pendingOp.opType = 0;
            return true;
        }
        return false;
    }

    /// @notice Returns the details of any pending operation to be approved.
    ///
    /// @param _orgId The org ID. This will be the org ID of network admin org.
    ///
    /// @return The org ID.
    /// @return The enode ID.
    /// @return The account.
    /// @return The operation type.
    function getPendingOpDetails(
        string calldata _orgId
    )
        external
        view
        onlyImplementation
        returns (string memory, string memory, address, uint256)
    {
        uint256 orgIndex = _getVoterOrgIndex(_orgId);
        return (
            orgVoterList[orgIndex].pendingOp.orgId,
            orgVoterList[orgIndex].pendingOp.enodeId,
            orgVoterList[orgIndex].pendingOp.account,
            orgVoterList[orgIndex].pendingOp.opType
        );
    }

    /// @notice Checks whether the voter account exists and is linked to the org.
    ///
    /// @param _orgId       The org ID.
    /// @param _vAccount    The voter account ID.
    ///
    /// @return True if the voter account exists and is linked to the org, false
    /// otherwise.
    function _checkVoterExists(
        string memory _orgId,
        address _vAccount
    ) internal view returns (bool) {
        uint256 orgIndex = _getVoterOrgIndex(_orgId);
        if (orgVoterList[orgIndex].voterIndex[_vAccount] == 0) {
            return false;
        }
        uint256 voterIndex = _getVoterIndex(_orgId, _vAccount);
        return orgVoterList[orgIndex].voterList[voterIndex].active;
    }

    /// @notice Checks whether the pending operation exists.
    ///
    /// @param _orgId       The org ID.
    /// @param _pendingOp   The type of operation.
    ///
    /// @return True if the pending operation exists, false otherwise.
    function _checkPendingOp(
        string memory _orgId,
        uint256 _pendingOp
    ) internal view returns (bool) {
        return (orgVoterList[_getVoterOrgIndex(_orgId)].pendingOp.opType ==
            _pendingOp);
    }

    /// @notice Returns the voter account index.
    ///
    /// @param _orgId       The org ID.
    /// @param _vAccount    The voter account ID.
    ///
    /// The voter account index.
    function _getVoterIndex(
        string memory _orgId,
        address _vAccount
    ) internal view returns (uint256) {
        uint256 orgIndex = _getVoterOrgIndex(_orgId);
        return orgVoterList[orgIndex].voterIndex[_vAccount] - 1;
    }

    //// @notice Returns the org index for the org from voter list.
    ///
    /// @param _orgId The org ID.
    ///
    /// @return The org index for the org from voter list.
    function _getVoterOrgIndex(
        string memory _orgId
    ) internal view returns (uint256) {
        return VoterOrgIndex[keccak256(abi.encode(_orgId))] - 1;
    }
}
