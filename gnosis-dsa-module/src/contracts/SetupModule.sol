// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

import "../interfaces/IGnosisSafe.sol";
import "./DaaDsaModule.sol";
import "./DaaModule.sol";


/// @title DAA Setup Module - A gnosis safe module to deploy and enable DAA modules.


contract SetupModule {

    IGnosisSafe public safe;
    IDSA public account;
    IInstaIndex instaIndex; 

    string public constant name = "DAA Setup Module";
    string public constant version  = "1";

    event SetupCompleted(address safe, address withdrawAddress, address withdrawModule , address dsaModule);

    constructor(){}

    /// @dev Initialize the DAA modules - Deploy and Enable
    /// @param _safe Safe address.
    /// @param withdrawAddress Client withdrawal address.
    /// @param _index Address of the Instadapp index contract.
    /// @param _chainId Chain id of the chain (e.g. 137 for polygon)
    function initialize(IGnosisSafe _safe, address withdrawAddress, IInstaIndex _index, uint256 _chainId) external {
            require(isAuthorized(msg.sender,_safe));
            DaaDsaModule dsaModule = new DaaDsaModule();
            DaaModule withdrawModule = new DaaModule(withdrawAddress, address(_safe));
            dsaModule.initialize(_safe,_index,_chainId);   
            enableModules(_safe, address(withdrawModule), address(dsaModule));
            emit SetupCompleted(address(_safe), withdrawAddress, address(withdrawModule), address(dsaModule));
    }

    function enableModules(IGnosisSafe safe, address wModuleAddress, address dsaModuleAddress) private {
            bytes memory data1 = abi.encodeWithSignature("enableModule(address)", wModuleAddress);
            require(safe.execTransactionFromModule(address(safe), 0, data1, Enum.Operation.Call), "Could not enable module");
            bytes memory data2 = abi.encodeWithSignature("enableModule(address)", dsaModuleAddress);
            require(safe.execTransactionFromModule(address(safe), 0, data2, Enum.Operation.Call), "Could not enable module");
    }

    function isAuthorized(address sender, IGnosisSafe safe) internal view returns (bool isOwner){
            address[] memory _owners = safe.getOwners();
            uint256 len = _owners.length;
            for (uint256 i = 0; i < len; i++) {
                if (_owners[i]==sender) { isOwner = true;}
            }
            require(isOwner, "Sender not authorized");
    }
}
