// SPDX-License-Identifier: unlicensed
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { GnosisSafe } from "../interfaces/IGnosisSafe.sol";
import { Adaptor} from "./connectors/Adaptor.sol";

import "./utils/Registry.sol";
import "./utils/Enum.sol";


interface IAdaptor{
    function calcNetAssetValue(address asset) external;
}


contract PositionManager is Registry {
    using EnumerableSet for EnumerableSet.AddressSet;

    enum LiquidityPool {Aave, Compound}

    mapping(string => LiquidityPool[]) private poolsByCurrency;
    // mapping token name to blockchain addresses
    mapping(string => address) private _erc20Contracts;
    // Enabled Connectors(Connector name => address)
    mapping(string => address) public _connectors;
    EnumerableSet.AddressSet private _connectorsList;

    GnosisSafe public _safe;

    constructor(GnosisSafe safe, string[] memory connectorsName, address[] memory connectorsAddress){
        _safe = safe;
        addConnectors(connectorsName,connectorsAddress);
    }


    function getNetPositionValue(address asset) external view returns (uint256) {
         uint length = _connectorsList.length();
         uint256 externalBalance = 0;
        for (uint i = 0; i < length; i++){
            externalBalance += Adaptor(_connectorsList.at(i)).getNetAssetValue(asset,address(_safe));
        }
        return externalBalance;
    }

    function addConnectors(string[] memory connectorsName, address[] memory connectorsAddress ) internal {
        uint length = connectorsAddress.length;
        for (uint i = 0; i < length; i++){
            _connectors[connectorsName[i]]  = connectorsAddress[i];
            _connectorsList.add(connectorsAddress[i]);
        }
        /* 
            - safety checks on connectors name/address
            - emit event
        */
    }

   
}
