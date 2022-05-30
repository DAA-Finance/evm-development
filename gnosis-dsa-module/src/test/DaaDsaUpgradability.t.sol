// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "../contracts/DaaDsaModule.sol";
import "../interfaces/IERC20Minimal.sol";
import "../interfaces/IDaaDsaModule.sol";
import "./utils/Cheats.sol";
import "../contracts/proxy/ProxyHandler.sol";

contract DaaDSAUpgradabilityTest is DSTest {
    
    DaaDsaModule daaDsaModule;
    IInstaIndex instaIndex = IInstaIndex(0xA9B99766E6C676Cf1975c0D3166F96C0848fF5ad); // this address is only of mainnet.
    // address safeAddress = 0x933966159085a669279025283A6d250B505f4E8C; // empty safe
    address safeAddress = 0x213997398DdD5BBd98309428fa3Ae017D5570603;
    address[] safeOwners;
    address instaIndexAddress = 0xA9B99766E6C676Cf1975c0D3166F96C0848fF5ad;

    address account1 = 0x1111100000000000000000000000000000000000;
    address account2 = 0x2222200000000000000000000000000000000000;
    address account3 = 0x3333300000000000000000000000000000000000;
    address account4 = 0x4444400000000000000000000000000000000000;
    address account5 = 0x5555500000000000000000000000000000000000;
    address account6 = 0x6666600000000000000000000000000000000000;
    address account7 = 0x7777700000000000000000000000000000000000;
    address account8 = 0x8888800000000000000000000000000000000000;

    CheatCodes internal constant cheats = CheatCodes(HEVM_ADDRESS);

    function setUp() public {
        daaDsaModule = new DaaDsaModule();
        // deploy proxy
        ProxyHandler proxy = new ProxyHandler(address(daaDsaModule));
        IDaaDsaModule proxyWrapped = IDaaDsaModule(address(proxy));
        proxyWrapped.initialize(IGnosisSafe(safeAddress),IInstaIndex(instaIndexAddress),137);
        
        //enable module
        cheats.prank(safeAddress);
        IGnosisSafe(safeAddress).enableModule(address(proxy));
        safeOwners = IGnosisSafe(safeAddress).getOwners();
        cheats.prank(safeOwners[0]); //safe owner
        proxyWrapped.createAccount(2,address(0));
    }

    /* ----------- TEST DSA CONNECTORS ------------ */


    function testAaveDepositAndWithdraw() public {
        // DSA creation 
        address _account = instaIndex.build(address(this), 2, address(0)); // 2 is the most recent DSA version
        //deposit funds into DSA
        (string[] memory targetsBasic, bytes[] memory dataBasic) = buildBasicDeposit();
        (address[] memory  tokenAddressBasic, uint[] memory amountBasic) = this.getConnectorData(targetsBasic, dataBasic);
        cheats.prank(0x4A35582a710E1F4b2030A3F826DA20BfB6703C09);
        IERC20Minimal(tokenAddressBasic[0]).transfer(address(this),amountBasic[0]);
        IERC20Minimal(tokenAddressBasic[0]).approve(_account,amountBasic[0]);
        IDSA(_account).cast(targetsBasic, dataBasic, address(0)); 
        // get mock tx data
        (string[] memory targets, bytes[] memory data) = buildAaveDeposit();
        // mock logic of connector check - data digest
        (address[] memory  tokenAddress, uint[] memory amount) = this.getConnectorData(targets, data);
        // emit log_address(tokenAddress[0]);
        // emit log_uint(amount[0]);
        for (uint i=0; i< data.length; i++){
            if (amount[i] > 0){
                if (tokenAddress[i] != address(0)){
                    // pull tokens if required (this would be from safe)  
                    cheats.prank(0x4A35582a710E1F4b2030A3F826DA20BfB6703C09);
                    IERC20Minimal(tokenAddress[i]).transfer(address(this),amount[i]);
                    // approve to DSA
                    IERC20Minimal(tokenAddress[i]).approve(_account,amount[i]);
                } else {
                    // pull ETH
                }
            }
        }
        // emit log_address(tokenAddress[1]);
        // emit log_uint(amount[1]);
        // cast to DSA
        IDSA(_account).cast(targets, data, address(0)); 
        assertTrue(IERC20Minimal(tokenAddressBasic[0]).balanceOf(address(this)) == 0);
        assertTrue(IERC20Minimal(tokenAddressBasic[0]).balanceOf(_account) == 0);
        (string[] memory targetsAaveWithdraw, bytes[] memory dataAaveWithdraw) = buildAaveWithdraw();
        IDSA(_account).cast(targetsAaveWithdraw, dataAaveWithdraw, address(0)); 
        assertTrue(IERC20Minimal(tokenAddressBasic[0]).balanceOf(_account) == amountBasic[0]);
    }

    function testAaveBorrowAndPayback() public {
        // DSA creation 
        address _account = instaIndex.build(address(this), 2, address(0)); // 2 is the most recent DSA version
        //deposit funds into DSA
        (string[] memory targetsBasic, bytes[] memory dataBasic) = buildBasicDeposit();
        (address[] memory  tokenAddressBasic, uint[] memory amountBasic) = this.getConnectorData(targetsBasic, dataBasic);
        cheats.prank(0x4A35582a710E1F4b2030A3F826DA20BfB6703C09);
        IERC20Minimal(tokenAddressBasic[0]).transfer(address(this),amountBasic[0]);
        IERC20Minimal(tokenAddressBasic[0]).approve(_account,amountBasic[0]);
        IDSA(_account).cast(targetsBasic, dataBasic, address(0)); 
        // deposit collateral into aave
        {
            (string[] memory targetsAaveDeposit, bytes[] memory dataAaveDeposit) = buildAaveDeposit();
            IDSA(_account).cast(targetsAaveDeposit, dataAaveDeposit, address(0)); 
        }        
        // get mock tx data
        (string[] memory targets, bytes[] memory data) = buildAaveBorrow();
        // mock logic of connector check - data digest
        (address[] memory  tokenAddress, uint[] memory amount) = this.getConnectorData(targets, data);
        // emit log_address(tokenAddress[0]);
        // emit log_uint(amount[0]);
        for (uint i=0; i< data.length; i++){
            if (amount[i] > 0){
                if (tokenAddress[i] != address(0)){
                    // pull tokens if required (this would be from safe)  
                    cheats.prank(0x4A35582a710E1F4b2030A3F826DA20BfB6703C09);
                    IERC20Minimal(tokenAddress[i]).transfer(address(this),amount[i]);
                    // approve to DSA
                    IERC20Minimal(tokenAddress[i]).approve(_account,amount[i]);
                } else {
                    // pull ETH
                }
            }
        }
        // emit log_address(tokenAddress[1]);
        // emit log_uint(amount[1]);
        // cast to DSA
        IDSA(_account).cast(targets, data, address(0)); 
        assertTrue(IERC20Minimal(tokenAddressBasic[0]).balanceOf(address(this)) == 0);
        // only borrowing half of amount deposited hence the / 2
        assertTrue(IERC20Minimal(tokenAddressBasic[0]).balanceOf(_account) == amountBasic[0]/2);
        (string[] memory targetsAavePayback, bytes[] memory dataAavePayback) = buildAavePayback();
        IDSA(_account).cast(targetsAavePayback, dataAavePayback, address(0)); 
        assertTrue(IERC20Minimal(tokenAddressBasic[0]).balanceOf(_account) == 0);
    }

    /* ----------- CONNECTOR UTILS ------------ */

    function buildBasicDeposit() public returns (string[] memory _targets, bytes[] memory _data) {

        // encoding data to run multiple things through cast on account
        // Depositing in DSA and then deposit in Compound through DSA.
        _targets = new string[](1);
        _data = new bytes[](1);
        
        _targets[0] = "BASIC-A";
        
        bytes4  basicDeposit = bytes4(keccak256("deposit(address,uint256,uint256,uint256)"));

        address dai = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
        uint amtToDeposit = 1e18; // 1 DAI
        // get some DAI from a random DAI-full address to Safe
        cheats.prank(0x4A35582a710E1F4b2030A3F826DA20BfB6703C09);
        IERC20Minimal(dai).transfer(safeAddress,amtToDeposit);

        _data[0] = abi.encodeWithSelector(basicDeposit, dai, amtToDeposit, 0, 0);
    }

    function buildBasicWithdraw() public returns (string[] memory _targets, bytes[] memory _data) {

        // encoding data to run multiple things through cast on account
        // Depositing in DSA and then deposit in Compound through DSA.
        _targets = new string[](1);
        _data = new bytes[](1);
        
        _targets[0] = "BASIC-A";
        
        bytes4  basicWithdraw = bytes4(keccak256("withdraw(address,uint256,address,uint256,uint256)"));

        address dai = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
        uint amtToDeposit = 1e18; // 1 DAI
        // get some DAI from a random DAI-full address to Safe
        cheats.prank(0x4A35582a710E1F4b2030A3F826DA20BfB6703C09);
        IERC20Minimal(dai).transfer(safeAddress,amtToDeposit);

        _data[0] = abi.encodeWithSelector(basicWithdraw, dai, amtToDeposit, address(this), 0, 0);
    }

    function buildAaveDeposit() public returns (string[] memory _targets, bytes[] memory _data) {

        // encoding data to run multiple things through cast on account
        // Depositing in DSA and then deposit in Compound through DSA.
        _targets = new string[](1);
        _data = new bytes[](1);
        
        _targets[0] = "AAVE-V2-A";
        
        bytes4  aaveDeposit = bytes4(keccak256("deposit(address,uint256,uint256,uint256)"));

        address dai = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
        uint amtToDeposit = 1e18; // 1 DAI
        // get some DAI from a random DAI-full address to Safe
        cheats.prank(0x4A35582a710E1F4b2030A3F826DA20BfB6703C09);
        IERC20Minimal(dai).transfer(safeAddress,amtToDeposit);

        _data[0] = abi.encodeWithSelector(aaveDeposit, dai, amtToDeposit, 0, 0);
    }

    function buildAaveWithdraw() public returns (string[] memory _targets, bytes[] memory _data) {

        // encoding data to run multiple things through cast on account
        // Depositing in DSA and then deposit in Compound through DSA.
        _targets = new string[](1);
        _data = new bytes[](1);
        
        _targets[0] = "AAVE-V2-A";
        
        bytes4  aaveWithdraw = bytes4(keccak256("withdraw(address,uint256,uint256,uint256)"));

        address dai = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
        uint amtToDeposit = 1e18; // 1 DAI
        // get some DAI from a random DAI-full address to Safe
        cheats.prank(0x4A35582a710E1F4b2030A3F826DA20BfB6703C09);
        IERC20Minimal(dai).transfer(safeAddress,amtToDeposit);

        _data[0] = abi.encodeWithSelector(aaveWithdraw, dai, amtToDeposit, 0, 0);
    }

    function buildAaveBorrow() public returns (string[] memory _targets, bytes[] memory _data) {

        // encoding data to run multiple things through cast on account
        // Depositing in DSA and then deposit in Compound through DSA.
        _targets = new string[](1);
        _data = new bytes[](1);
        
        _targets[0] = "AAVE-V2-A";
        
        bytes4  aaveBorrow = bytes4(keccak256("borrow(address,uint256,uint256,uint256,uint256)"));

        address dai = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
        uint amtToBorrow = 1e18 / 2; // 1 DAI
        // get some DAI from a random DAI-full address to Safe
        cheats.prank(0x4A35582a710E1F4b2030A3F826DA20BfB6703C09);
        IERC20Minimal(dai).transfer(safeAddress,amtToBorrow);

        _data[0] = abi.encodeWithSelector(aaveBorrow, dai, amtToBorrow, 2, 0, 0);
    }

    function buildAavePayback() public returns (string[] memory _targets, bytes[] memory _data) {

        // encoding data to run multiple things through cast on account
        // Depositing in DSA and then deposit in Compound through DSA.
        _targets = new string[](1);
        _data = new bytes[](1);
        
        _targets[0] = "AAVE-V2-A";
        
        bytes4  aavePayback = bytes4(keccak256("payback(address,uint256,uint256,uint256,uint256)"));

        address dai = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
        uint amtToPayback = 1e18 / 2; // 1 DAI
        // get some DAI from a random DAI-full address to Safe
        cheats.prank(0x4A35582a710E1F4b2030A3F826DA20BfB6703C09);
        IERC20Minimal(dai).transfer(safeAddress,amtToPayback);

        _data[0] = abi.encodeWithSelector(aavePayback, dai, amtToPayback, 2, 0, 0);
    }

    function buildAaveEnableCollateral() public returns (string[] memory _targets, bytes[] memory _data) {

        // encoding data to run multiple things through cast on account
        // Depositing in DSA and then deposit in Compound through DSA.
        _targets = new string[](1);
        _data = new bytes[](1);
        address[] memory tokens = new address[](1);
        
        _targets[0] = "AAVE-V2-A";
        
        bytes4  aaveEnableCollateral = bytes4(keccak256("enableCollateral(address[])"));

        address dai = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
        tokens[0] = dai;
        uint amtToDeposit = 1e18; // 1 DAI
        // get some DAI from a random DAI-full address to Safe
        cheats.prank(0x4A35582a710E1F4b2030A3F826DA20BfB6703C09);
        IERC20Minimal(dai).transfer(safeAddress,amtToDeposit);

        _data[0] = abi.encodeWithSelector(aaveEnableCollateral, tokens);
    }

    function buildAaveSwapBorrowRateMode() public returns (string[] memory _targets, bytes[] memory _data) {

        // encoding data to run multiple things through cast on account
        // Depositing in DSA and then deposit in Compound through DSA.
        _targets = new string[](1);
        _data = new bytes[](1);
        
        _targets[0] = "AAVE-V2-A";
        
        bytes4  aaveSwapBorrowRateMode = bytes4(keccak256("swapBorrowRateMode(address, uint256)"));

        address dai = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
        uint amtToDeposit = 1e18; // 1 DAI
        // get some DAI from a random DAI-full address to Safe
        cheats.prank(0x4A35582a710E1F4b2030A3F826DA20BfB6703C09);
        IERC20Minimal(dai).transfer(safeAddress,amtToDeposit);

        _data[0] = abi.encodeWithSelector(aaveSwapBorrowRateMode, dai,2);
    }

    function getConnectorData(string[] memory connectorId, bytes[] calldata data) public view returns (address[] memory addrList, uint[] memory amtList) {
        uint len = data.length;
        addrList = new address[](len);
        amtList = new uint[](len);
        for (uint i = 0; i < len; i++){
            if (keccak256(abi.encodePacked(connectorId[i])) == keccak256("BASIC-A")){
                if (bytes4(data[i][:4]) == bytes4(keccak256("deposit(address,uint256,uint256,uint256)"))){
                    (address a, uint b, , ) = abi.decode(data[i][4:], (address, uint, uint, uint));
                    addrList[i] = a;
                    amtList[i] = b;
                } else if (bytes4(data[i][:4]) == bytes4(keccak256("withdraw(address,uint256,address,uint256,uint256)"))){
                    (address a, uint b, address to, , ) = abi.decode(data[i][4:], (address, uint,address, uint, uint));
                    addrList[i] = a;
                    amtList[i] = b;
                    require(to == address(this),"NoExt");
                }
            } else {
                addrList[i] = address(0);
                amtList[i] = 0;
            }
        }
    }
    
}
