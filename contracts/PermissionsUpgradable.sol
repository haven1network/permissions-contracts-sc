pragma solidity ^0.5.3;

import "./PermissionsInterface.sol";

/// @title PermissionsUpgradable
///
/// @notice This contract holds the address of current Permissions Implementation
/// contract. The contract is owned by a guardian account. Only the guardian
/// can change the implementation contract address as business needs.
contract PermissionsUpgradable {
    address private guardian;
    address private permImpl;
    address private permInterface;

    /// @dev initDone ensures that init can be called only once.
    bool private initDone;

    /// @param _guardian The guardian account address.
    constructor(address _guardian) public {
        guardian = _guardian;
        initDone = false;
    }

    /// @notice Confirms that the caller is the guardian account.
    modifier onlyGuardian() {
        require(msg.sender == guardian, "invalid caller");
        _;
    }

    /// @notice Executed by the guardian. Links the Permissions Interface and
    /// Permissions Implementation contract addresses.
    ///
    /// @param _permInterface   The Permissions Interface contract address.
    /// @param _permImpl        The Permissions Implementation contract address.
    function init(
        address _permInterface,
        address _permImpl
    ) external onlyGuardian {
        require(!initDone, "can be executed only once");
        permImpl = _permImpl;
        permInterface = _permInterface;
        _setImpl(permImpl);
        initDone = true;
    }

    /// @notice Executed by guardian. Changes ownership of the guardian to
    /// a nominated address.
    ///
    /// @param _updatedGuardian The new guardian address.
    function changeGuardian(address _updatedGuardian) public onlyGuardian {
        guardian = _updatedGuardian;
    }

    /// @notice Changes the Permissions Implementation contract address.
    ///
    /// @param _proposedImpl address of the new permissions implementation contract
    ///
    /// @dev Can be executed by guardian account only.
    function confirmImplChange(address _proposedImpl) public onlyGuardian {
        // The policy details needs to be carried forward from existing
        // implementation to new. So first these are read from existing
        // implementation and then updated in new implementation.
        (
            string memory adminOrg,
            string memory adminRole,
            string memory orgAdminRole,
            bool bootStatus
        ) = PermissionsImplementation(permImpl).getPolicyDetails();
        _setPolicy(
            _proposedImpl,
            adminOrg,
            adminRole,
            orgAdminRole,
            bootStatus
        );
        permImpl = _proposedImpl;
        _setImpl(permImpl);
    }

    /// @notice Fetches the guardian account address.
    ///
    /// @return The guardian account address.
    function getGuardian() public view returns (address) {
        return guardian;
    }

    /// @notice Fetches the Permissions Implementation address.
    ///
    /// @return The Permissions Implementation address.
    function getPermImpl() public view returns (address) {
        return permImpl;
    }

    /// @notice Fetches the Permissions Interface address.
    ///
    /// @return The Permissions Interface address.
    function getPermInterface() public view returns (address) {
        return permInterface;
    }

    /// @notice Sets the permissions policy details in the Permissions
    /// Implementation contract.
    ///
    /// @param _permImpl        The Permissions Implementation contract address.
    /// @param _adminOrg        The name of the admin organization.
    /// @param _adminRole       The name of the admin role.
    /// @param _orgAdminRole    The name of the default organization admin role.
    /// @param _bootStatus      The network boot status.
    function _setPolicy(
        address _permImpl,
        string memory _adminOrg,
        string memory _adminRole,
        string memory _orgAdminRole,
        bool _bootStatus
    ) private {
        PermissionsImplementation(_permImpl).setMigrationPolicy(
            _adminOrg,
            _adminRole,
            _orgAdminRole,
            _bootStatus
        );
    }

    /// @notice Sets the Permissions Implementation contract address in the
    /// Permissions Interface contract.
    ///
    /// @param _permImpl The Permissions Implementation contract address.
    function _setImpl(address _permImpl) private {
        PermissionsInterface(permInterface).setPermImplementation(_permImpl);
    }
}
