// SPDX-License-Identifier: unlicensed
pragma solidity >=0.6.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


contract TokenizedShare is ERC20, AccessControl {
    

    uint8 immutable _decimals;

        bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor(address daaModule) public ERC20 ("Module Deposit Tokenized","dDAA"){
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender); // just for testing
        _setupRole(MINTER_ROLE, daaModule);
        _decimals = 6;
    }

    /// @dev Call to mint tokens to address on deposit
    /// @param account Address receiving tokens
    /// @param amount Number of tokens to mint
    function mint(address account, uint256 amount) public returns (bool) {
        require(hasRole(MINTER_ROLE, msg.sender), "Caller is not an admin");
        // Mint and return true
        _mint(account, amount);
        return true;
    }

    function burn(address _sender,uint256 amount) external {
        require(hasRole(MINTER_ROLE, msg.sender), "Caller is not an admin");
        // Burn - 
        _burn(_sender, amount);
    }

    function mintInitialSupply(address safe) external returns (bool) {
        require(hasRole(MINTER_ROLE, msg.sender), "Caller is not an admin");
        require(totalSupply() == 0, "Already initialized");
         // Mint and return true
        _mint(safe, 10**6);
        return true;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

}