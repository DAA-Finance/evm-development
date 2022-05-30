// SPDX-License-Identifier: unlicensed
pragma solidity >=0.7.0 <0.9.0;

abstract contract Adaptor {

    function getNetAssetValue(address asset, address _target) external view returns (uint256) {
        return getGrossValue(asset, _target) - getGrossDebt(asset,_target);
    }

    function getGrossValue(address asset, address _target) public virtual view returns (uint grossValue);

    function getGrossDebt(address asset, address _target) public virtual view returns (uint grossDebt);

}