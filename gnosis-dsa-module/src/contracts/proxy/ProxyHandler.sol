// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract ProxyHandler is ERC1967Proxy, Ownable{

    constructor(address initContract) ERC1967Proxy(initContract,""){
        _changeAdmin(msg.sender);
    }

    function getImplementation() external view returns (address){
        return _implementation();
    }

    function getAdmin() external view returns (address){
        return _getAdmin();
    }

    function changeAdmin(address newAdmin) external onlyOwner {
        _changeAdmin(newAdmin);
    }
}
