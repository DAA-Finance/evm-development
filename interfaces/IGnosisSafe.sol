// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.6.0;

import "../contracts/Enum.sol";

interface IGnosisSafe {
    /// @dev Allows a Module to execute a Safe transaction without any further confirmations.
    /// @param to Destination address of module transaction.
    /// @param value Ether value of module transaction.
    /// @param data Data payload of module transaction.
    /// @param operation Operation type of module transaction.
    function execTransactionFromModule(address to, uint256 value, bytes calldata data, Enum.Operation operation)
        external
        returns (bool success);
    
    function getOwners() external view returns (address[] memory);

    function enableModule(address module) external;
}