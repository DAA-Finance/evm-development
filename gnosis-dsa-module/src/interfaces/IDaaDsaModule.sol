// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./IGnosisSafe.sol";
import {IInstaIndex} from "../contracts/DaaDsaModule.sol";
import {IDSA} from "../contracts/DaaDsaModule.sol";

interface IDaaDsaModule {

    function initialize(IGnosisSafe _safe, IInstaIndex _index, uint256 _chainId) external;
    
    function executeTransaction(
        string[] calldata _targetNames,
        bytes[] calldata _datas,
        bytes memory signatures
    ) external;

    function createAccount(uint accountVersion, address accountOrigin)
        external 
        returns (IDSA);

    function approveHash(bytes32 hashToApprove) external;

}