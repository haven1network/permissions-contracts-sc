pragma solidity ^0.5.3;

import "./PermissionsUpgradable.sol";

/// @title NodeManager
///
/// @notice This contract holds the implementation logic for all node management
/// functionality. This contract can only be called into by the `PermissionsImplementation`
/// contract.
///
/// There are a number of view functions exposed as public and can be called directly.
/// These are invoked by Quorum for populating permissions data in cache.
///
/// @dev Node status is denoted by a fixed integer value. The values are as
/// below:
///
/// -   0: Not in list
/// -   1: Node pending approval
/// -   2: Active
/// -   3: Deactivated
/// -   4: Blacklisted
/// -   5: Blacklisted node recovery initiated. Once approved the node status
///     will be updated to Active (2)
///
/// Once the node is blacklisted no further activity on the node is possible.
contract NodeManager {
    PermissionsUpgradable private permUpgradable;

    struct NodeDetails {
        string enodeId;
        string ip;
        uint16 port;
        uint16 raftPort;
        string orgId;
        uint256 status;
    }

    // Use an array to store node details if we want to list all node one day,
    /// mapping is not capable.
    NodeDetails[] private nodeList;

    // Mapping of enode ID to array index to track node.
    mapping(bytes32 => uint256) private nodeIdToIndex;

    // Mapping of enodeId to array index to track node.
    mapping(bytes32 => uint256) private enodeIdToIndex;

    // Tracking total number of nodes in network.
    uint256 private numberOfNodes;

    // Node permission events for new node propose.
    event NodeProposed(
        string _enodeId,
        string _ip,
        uint16 _port,
        uint16 _raftport,
        string _orgId
    );

    event NodeApproved(
        string _enodeId,
        string _ip,
        uint16 _port,
        uint16 _raftport,
        string _orgId
    );

    // Node permission events for node deactivation.
    event NodeDeactivated(
        string _enodeId,
        string _ip,
        uint16 _port,
        uint16 _raftport,
        string _orgId
    );

    // Node permission events for node activation.
    event NodeActivated(
        string _enodeId,
        string _ip,
        uint16 _port,
        uint16 _raftport,
        string _orgId
    );

    // Node permission events for node blacklist.
    event NodeBlacklisted(
        string _enodeId,
        string _ip,
        uint16 _port,
        uint16 _raftport,
        string _orgId
    );

    // Node permission events for initiating the recovery of blacklisted node.
    event NodeRecoveryInitiated(
        string _enodeId,
        string _ip,
        uint16 _port,
        uint16 _raftport,
        string _orgId
    );

    // Node permission events for completing the recovery of blacklisted node.
    event NodeRecoveryCompleted(
        string _enodeId,
        string _ip,
        uint16 _port,
        uint16 _raftport,
        string _orgId
    );

    /// @notice Confirms that the caller is the PermissionsImplementation contract.
    modifier onlyImplementation() {
        require(msg.sender == permUpgradable.getPermImpl(), "invalid caller");
        _;
    }

    /// @notice Checks if the node exists in the network.
    ///
    /// @param _enodeId The full enode ID.
    modifier enodeExists(string memory _enodeId) {
        require(
            enodeIdToIndex[keccak256(abi.encode(_enodeId))] != 0,
            "passed enode id does not exist"
        );
        _;
    }

    /// @notice Checks if the node does not exist in the network.
    ///
    /// @param _enodeId The full enode ID.
    modifier enodeDoesNotExists(string memory _enodeId) {
        require(
            enodeIdToIndex[keccak256(abi.encode(_enodeId))] == 0,
            "passed enode id exists"
        );
        _;
    }

    /// @notice  Sets the PermissionsUpgradable address.
    ///
    /// @param _permUpgradable The PermissionsUpgradable contract address.
    constructor(address _permUpgradable) public {
        permUpgradable = PermissionsUpgradable(_permUpgradable);
    }

    /// @notice Fetches the node details for a given an enode ID.
    /// @param _enodeId The full enode ID
    ///
    /// @return The node's org ID.
    /// @return The node's enode ID.
    /// @return The node's IP.
    /// @return The node's port.
    /// @return The node's raft port.
    /// @return The node's status.
    function getNodeDetails(
        string calldata enodeId
    )
        external
        view
        returns (
            string memory _orgId,
            string memory _enodeId,
            string memory _ip,
            uint16 _port,
            uint16 _raftport,
            uint256 _nodeStatus
        )
    {
        if (nodeIdToIndex[keccak256(abi.encode(_enodeId))] == 0) {
            return ("", "", "", 0, 0, 0);
        }
        uint256 nodeIndex = _getNodeIndex(enodeId);
        return (
            nodeList[nodeIndex].orgId,
            nodeList[nodeIndex].enodeId,
            nodeList[nodeIndex].ip,
            nodeList[nodeIndex].port,
            nodeList[nodeIndex].raftPort,
            nodeList[nodeIndex].status
        );
    }

    /// @notice Fetches the node details for a given node index.
    ///
    /// @param _nodeIndex The node index.
    ///
    /// @return The node's org ID.
    /// @return The node's enode ID.
    /// @return The node's IP.
    /// @return The node's port.
    /// @return The node's raft port.
    /// @return The node's status.
    function getNodeDetailsFromIndex(
        uint256 _nodeIndex
    )
        external
        view
        returns (
            string memory _orgId,
            string memory _enodeId,
            string memory _ip,
            uint16 _port,
            uint16 _raftport,
            uint256 _nodeStatus
        )
    {
        return (
            nodeList[_nodeIndex].orgId,
            nodeList[_nodeIndex].enodeId,
            nodeList[_nodeIndex].ip,
            nodeList[_nodeIndex].port,
            nodeList[_nodeIndex].raftPort,
            nodeList[_nodeIndex].status
        );
    }

    /// @notice Returns the total number of nodes in the network.
    ///
    /// @return The total number of nodes in the network.
    function getNumberOfNodes() external view returns (uint256) {
        return numberOfNodes;
    }

    /// @notice Called at the time of network initialization for adding admin
    /// nodes.
    ///
    /// @param _enodeId     The enode ID
    /// @param _ip          The IP of the node.
    /// @param _port        The TCP port of the node.
    /// @param _raftport    The raft port of the node.
    /// @param _orgId       The org ID to which the enode belongs.
    function addAdminNode(
        string memory _enodeId,
        string memory _ip,
        uint16 _port,
        uint16 _raftport,
        string memory _orgId
    ) public onlyImplementation enodeDoesNotExists(_enodeId) {
        numberOfNodes++;
        enodeIdToIndex[keccak256(abi.encode(_enodeId))] = numberOfNodes;
        nodeList.push(NodeDetails(_enodeId, _ip, _port, _raftport, _orgId, 2));
        emit NodeApproved(_enodeId, _ip, _port, _raftport, _orgId);
    }

    /// @notice Called when a new org is created to add a node to the org.
    ///
    /// @param _enodeId     The enode ID
    /// @param _ip          The IP of the node.
    /// @param _port        The TCP port of the node.
    /// @param _raftport    The raft port of the node.
    /// @param _orgId       The org ID to which the enode belongs.
    function addNode(
        string memory _enodeId,
        string memory _ip,
        uint16 _port,
        uint16 _raftport,
        string memory _orgId
    ) public onlyImplementation enodeDoesNotExists(_enodeId) {
        numberOfNodes++;
        enodeIdToIndex[keccak256(abi.encode(_enodeId))] = numberOfNodes;
        nodeList.push(NodeDetails(_enodeId, _ip, _port, _raftport, _orgId, 1));
        emit NodeProposed(_enodeId, _ip, _port, _raftport, _orgId);
    }

    /// @notice Called by org admins to add new nodes to the org or sub orgs.
    ///
    /// @param _enodeId     The enode ID
    /// @param _ip          The IP of the node.
    /// @param _port        The TCP port of the node.
    /// @param _raftport    The raft port of the node.
    /// @param _orgId       The org ID to which the enode belongs.
    function addOrgNode(
        string memory _enodeId,
        string memory _ip,
        uint16 _port,
        uint16 _raftport,
        string memory _orgId
    ) public onlyImplementation enodeDoesNotExists(_enodeId) {
        numberOfNodes++;
        enodeIdToIndex[keccak256(abi.encode(_enodeId))] = numberOfNodes;
        nodeList.push(NodeDetails(_enodeId, _ip, _port, _raftport, _orgId, 2));
        emit NodeApproved(_enodeId, _ip, _port, _raftport, _orgId);
    }

    /// @notice Approves the addition of a node. Only called at the time where
    /// the master org is created by a Network Admin.
    ///
    /// @param _enodeId     The enode ID
    /// @param _ip          The IP of the node.
    /// @param _port        The TCP port of the node.
    /// @param _raftport    The raft port of the node.
    /// @param _orgId       The org ID to which the enode belongs.
    function approveNode(
        string memory _enodeId,
        string memory _ip,
        uint16 _port,
        uint16 _raftport,
        string memory _orgId
    ) public onlyImplementation enodeExists(_enodeId) {
        // node should belong to the passed org
        require(
            _checkOrg(_enodeId, _orgId),
            "enode id does not belong to the passed org id"
        );
        require(_getNodeStatus(_enodeId) == 1, "nothing pending for approval");
        uint256 nodeIndex = _getNodeIndex(_enodeId);
        if (
            keccak256(abi.encode(nodeList[nodeIndex].ip)) !=
            keccak256(abi.encode(_ip)) ||
            nodeList[nodeIndex].port != _port ||
            nodeList[nodeIndex].raftPort != _raftport
        ) {
            return;
        }
        nodeList[nodeIndex].status = 2;
        emit NodeApproved(
            nodeList[nodeIndex].enodeId,
            _ip,
            _port,
            _raftport,
            nodeList[nodeIndex].orgId
        );
    }

    /// @notice Updates the status of a node. Can be called for deactivating or
    /// blacklisting, as well as reactivating a deactivated node.
    ///
    /// @param _enodeId     The enode ID
    /// @param _ip          The IP of the node.
    /// @param _port        The TCP port of the node.
    /// @param _raftport    The raft port of the node.
    /// @param _orgId       The org ID to which the enode belongs.
    /// @param _action      The action being performed.
    ///
    /// @dev The action can have any of the following values:
    ///
    /// -   1: Suspend the node
    /// -   2: Revoke suspension of a suspended node
    /// -   3: Blacklist a node
    /// -   4: Initiate the recovery of a blacklisted node
    /// -   5: Blacklisted node recovery fully approved. Mark to active.
    function updateNodeStatus(
        string memory _enodeId,
        string memory _ip,
        uint16 _port,
        uint16 _raftport,
        string memory _orgId,
        uint256 _action
    ) public onlyImplementation enodeExists(_enodeId) {
        // The node should belong to the org.
        require(
            _checkOrg(_enodeId, _orgId),
            "enode id does not belong to the passed org"
        );
        require(
            (_action == 1 ||
                _action == 2 ||
                _action == 3 ||
                _action == 4 ||
                _action == 5),
            "invalid operation. wrong action passed"
        );

        uint256 nodeIndex = _getNodeIndex(_enodeId);
        if (
            keccak256(abi.encode(nodeList[nodeIndex].ip)) !=
            keccak256(abi.encode(_ip)) ||
            nodeList[nodeIndex].port != _port ||
            nodeList[nodeIndex].raftPort != _raftport
        ) {
            return;
        }

        if (_action == 1) {
            require(
                _getNodeStatus(_enodeId) == 2,
                "operation cannot be performed"
            );
            nodeList[nodeIndex].status = 3;
            emit NodeDeactivated(_enodeId, _ip, _port, _raftport, _orgId);
        } else if (_action == 2) {
            require(
                _getNodeStatus(_enodeId) == 3,
                "operation cannot be performed"
            );
            nodeList[nodeIndex].status = 2;
            emit NodeActivated(_enodeId, _ip, _port, _raftport, _orgId);
        } else if (_action == 3) {
            nodeList[nodeIndex].status = 4;
            emit NodeBlacklisted(_enodeId, _ip, _port, _raftport, _orgId);
        } else if (_action == 4) {
            // node should be in blacklisted state
            require(
                _getNodeStatus(_enodeId) == 4,
                "operation cannot be performed"
            );
            nodeList[nodeIndex].status = 5;
            emit NodeRecoveryInitiated(_enodeId, _ip, _port, _raftport, _orgId);
        } else {
            // node should be in initiated recovery state
            require(
                _getNodeStatus(_enodeId) == 5,
                "operation cannot be performed"
            );
            nodeList[nodeIndex].status = 2;
            emit NodeRecoveryCompleted(_enodeId, _ip, _port, _raftport, _orgId);
        }
    }

    // -------------------------------------------------------------------------
    // Private Functions

    /// @notice Returns the node index for given enode ID.
    ///
    /// @param _enodeId The enode ID.
    ///
    /// @return The node index.
    function _getNodeIndex(
        string memory _enodeId
    ) internal view returns (uint256) {
        return enodeIdToIndex[keccak256(abi.encode(_enodeId))] - 1;
    }

    /// @notice Checks if a given enode ID is linked to the provided org ID.
    ///
    /// @param _enodeId The enode ID.
    /// @param _orgId   The org ID or sub org ID to which the enode belongs.
    ///
    /// @return True if the given enode ID is linked to the provided org ID,
    /// false otherwise.
    function _checkOrg(
        string memory _enodeId,
        string memory _orgId
    ) internal view returns (bool) {
        return (keccak256(
            abi.encode(nodeList[_getNodeIndex(_enodeId)].orgId)
        ) == keccak256(abi.encode(_orgId)));
    }

    /// @notice Returns the node status for a given enode ID.
    ///
    /// @param _enodeId The enode ID.
    ///
    /// @return The node status for a given enode ID.
    function _getNodeStatus(
        string memory _enodeId
    ) internal view returns (uint256) {
        if (enodeIdToIndex[keccak256(abi.encode(_enodeId))] == 0) {
            return 0;
        }
        return nodeList[_getNodeIndex(_enodeId)].status;
    }

    /// @notice Checks whether the node is allowed to connect.
    ///
    /// @param _enodeId The enode ID.
    /// @param _ip      The IP of the node.
    /// @param _port    The TCP port of the node.
    ///
    /// @return True is the node can connect, false otherwise.
    function connectionAllowed(
        string memory _enodeId,
        string memory _ip,
        uint16 _port
    ) public view onlyImplementation returns (bool) {
        if (enodeIdToIndex[keccak256(abi.encode(_enodeId))] == 0) {
            return false;
        }
        uint256 nodeIndex = _getNodeIndex(_enodeId);
        if (
            nodeList[nodeIndex].status == 2 &&
            keccak256(abi.encode(nodeList[nodeIndex].ip)) ==
            keccak256(abi.encode(_ip))
        ) {
            return true;
        }

        return false;
    }
}
