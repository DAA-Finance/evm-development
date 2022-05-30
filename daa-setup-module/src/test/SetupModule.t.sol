// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "../contracts/SetupModule.flattened.sol";

interface CheatCodes {
    function prank(address) external;
    function roll(uint256) external;
    function assume(bool) external;
    function expectRevert(bytes calldata msg) external;
    event log(string);
    event log_uint(uint);
    event log_address(address);
    event log_bytes(bytes);
    event log_bytes32(bytes);
}

contract SetupModuleTest is DSTest {

    IInstaIndex instaIndex = IInstaIndex(0xA9B99766E6C676Cf1975c0D3166F96C0848fF5ad); // this address is only of mainnet.
    // address safeAddress = 0x933966159085a669279025283A6d250B505f4E8C; // empty safe
    address safeAddress = 0x213997398DdD5BBd98309428fa3Ae017D5570603;
    address[] safeOwners;
    address instaIndexAddress = 0xA9B99766E6C676Cf1975c0D3166F96C0848fF5ad;
    address usdc = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174; // polygon

    address account1 = 0x1111100000000000000000000000000000000000;
    address account2 = 0x2222200000000000000000000000000000000000;
    address account3 = 0x3333300000000000000000000000000000000000;
    address account4 = 0x4444400000000000000000000000000000000000;
    address account5 = 0x5555500000000000000000000000000000000000;
    address account6 = 0x6666600000000000000000000000000000000000;
    address account7 = 0x7777700000000000000000000000000000000000;
    address account8 = 0x8888800000000000000000000000000000000000;

    CheatCodes constant cheats = CheatCodes(HEVM_ADDRESS);

    function setUp() public {
        safeOwners = IGnosisSafe(safeAddress).getOwners();
        // load safe with usdc
        cheats.prank(0xF977814e90dA44bFA03b6295A0616a897441aceC);
        IERC20Minimal(usdc).transfer(safeAddress, 10e6);
    }

    function testSetup() public {
        SetupModule setupModule = new SetupModule();
        cheats.prank(safeAddress);
        IGnosisSafe(safeAddress).enableModule(address(setupModule));
        cheats.prank(safeOwners[0]);
        setupModule.initialize(IGnosisSafe(safeAddress),account1, IInstaIndex(instaIndexAddress), 2, address(0),137);
        // emit SetupCompleted(safe: 0x213997398ddd5bbd98309428fa3ae017d5570603, withdrawAddress: 0x1111100000000000000000000000000000000000, withdrawModule: DaaModule: [0x566B72091192CCd7013AdF77E2a1b349564acC21], dsaModule: DaaDsaModule: [0x037FC82298142374d974839236D2e2dF6B5BdD8F])
    }

    function testExecution() public {
        SetupModule setupModule = new SetupModule();
        cheats.prank(safeAddress);
        IGnosisSafe(safeAddress).enableModule(address(setupModule));
        cheats.prank(safeOwners[0]);
        setupModule.initialize(IGnosisSafe(safeAddress),account1, IInstaIndex(instaIndexAddress), 2, address(0),137);
        
        DaaDsaModule daaDsaModule = DaaDsaModule(0x037FC82298142374d974839236D2e2dF6B5BdD8F);

        address owner1 = safeOwners[0];
        address owner2 = safeOwners[1];
        // get mock tx data
        (string[] memory targets, bytes[] memory data) = buildOnly();
        bytes32 hash = daaDsaModule.getTransactionHash(targets,data,0);

        cheats.prank(owner1); //safe owner
        daaDsaModule.approveHash(hash);
        // 65 bytes -> padded to 32, padded to 32, 01 (sig type) - (e.g. https://github.com/safe-global/safe-contracts/blob/v1.0.0/test/gnosisSafeTeamEdition.js) 
        bytes memory sig1 = mergeBytes(abi.encode(address(owner1),0),abi.encodePacked(bytes1(uint8(1))));
        
        cheats.prank(owner2); //safe owner
        daaDsaModule.approveHash(hash);
        bytes memory sig2 = mergeBytes(abi.encode(address(owner2),0),abi.encodePacked(bytes1(uint8(1))));
        
        bytes memory sigs = abi.encodePacked(sig1,sig2);
        // emit log_bytes(sigs);

        // safe balance before TX
        address dai = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
        uint amtToDeposit = 1e18; // 1 DAI
        assertTrue(IERC20Minimal(dai).balanceOf(safeAddress) == amtToDeposit);
        cheats.prank(owner1); //safe owner
        daaDsaModule.executeTransaction(targets,data,sigs);
        assertTrue(IERC20Minimal(dai).balanceOf(safeAddress) == 0);
    }

    function testBlacklistedWithdraw() public {
        SetupModule setupModule = new SetupModule();
        cheats.prank(safeAddress);
        IGnosisSafe(safeAddress).enableModule(address(setupModule));
        cheats.prank(safeOwners[0]);
        setupModule.initialize(IGnosisSafe(safeAddress),account1, IInstaIndex(instaIndexAddress), 2, address(0),137);
        
        DaaDsaModule daaDsaModule = DaaDsaModule(0x037FC82298142374d974839236D2e2dF6B5BdD8F);
        // DSA creation 
        instaIndex.build(address(this), 2, address(0)); // 2 is the most recent DSA version
        // get mock tx data expected to Fail
        (string[] memory targets, bytes[] memory data) = buildOnlyBlackWithdraw();
        // mock logic of connector check - data digest
        // will fail and revert if no auth op
        cheats.expectRevert(bytes("NoExt"));
        daaDsaModule.getConnectorData(targets, data);
    }   


    function testBlacklistedAuthorityChange() public {
        SetupModule setupModule = new SetupModule();
        cheats.prank(safeAddress);
        IGnosisSafe(safeAddress).enableModule(address(setupModule));
        cheats.prank(safeOwners[0]);
        setupModule.initialize(IGnosisSafe(safeAddress),account1, IInstaIndex(instaIndexAddress), 2, address(0),137);
        
        DaaDsaModule daaDsaModule = DaaDsaModule(0x037FC82298142374d974839236D2e2dF6B5BdD8F);
        // DSA creation 
        instaIndex.build(address(this), 2, address(0)); // 2 is the most recent DSA version
        // get mock tx data expected to Fail
        (string[] memory targets, bytes[] memory data) = buildOnlyBlackAuth();
        // mock logic of connector check - data digest
        // will fail and revert if no auth op
        cheats.expectRevert(bytes("NoAuth"));
        daaDsaModule.getConnectorData(targets, data);
    }  

    function testWithdrawModule() public {
        SetupModule setupModule = new SetupModule();
        cheats.prank(safeAddress);
        IGnosisSafe(safeAddress).enableModule(address(setupModule));
        cheats.prank(safeOwners[0]);
        setupModule.initialize(IGnosisSafe(safeAddress),account1, IInstaIndex(instaIndexAddress), 2, address(0),137);
        
        DaaModule daaModule = DaaModule(0x566B72091192CCd7013AdF77E2a1b349564acC21);
        uint96 amount = 1e6;
        cheats.prank(safeOwners[0]);
        daaModule.executeTransfer(usdc, amount);
        assertTrue(IERC20Minimal(usdc).balanceOf(account1)==amount);
    }


    /* ----------- UTILS ------------ */

    function buildOnly() public returns (string[] memory _targets, bytes[] memory _data) {

        // encoding data to run multiple things through cast on account
        // Depositing in DSA and then deposit in Compound through DSA.
        _targets = new string[](2);
        _data = new bytes[](2);
        
        _targets[0] = "BASIC-A";
        _targets[1] = "AAVE-V2-A";
        
        bytes4  basicDeposit = bytes4(keccak256("deposit(address,uint256,uint256,uint256)"));
        bytes4  aaveDeposit = bytes4(keccak256("deposit(address,uint256,uint256,uint256)"));
        
        address dai = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
        uint amtToDeposit = 1e18; // 1 DAI
        // get some DAI from a random DAI-full address to Safe
        cheats.prank(0x4A35582a710E1F4b2030A3F826DA20BfB6703C09);
        IERC20Minimal(dai).transfer(safeAddress,amtToDeposit);

        _data[0] = abi.encodeWithSelector(basicDeposit, dai, amtToDeposit, 0, 0);
        _data[1] = abi.encodeWithSelector(aaveDeposit, dai, amtToDeposit, 0, 0);
        
    }

        function buildOnlyBlackWithdraw() public pure returns (string[] memory _targets, bytes[] memory _data) {

        // encoding data to run multiple things through cast on account
        // Depositing in DSA and then deposit in Compound through DSA.
        _targets = new string[](2);
        _data = new bytes[](2);
        
        _targets[0] = "BASIC-A";
        _targets[1] = "BASIC-A";
        
        bytes4  basicDeposit = bytes4(keccak256("deposit(address,uint256,uint256,uint256)"));
        bytes4  basicWithdrawExt = bytes4(keccak256("withdraw(address,uint256,address,uint256,uint256)"));
        
        address dai = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
        uint amtToDeposit = 1e18; // 1 DAI

        _data[0] = abi.encodeWithSelector(basicDeposit, dai, amtToDeposit, 0, 0);
        // withdraw to not auth ext address
        _data[1] = abi.encodeWithSelector(basicWithdrawExt, dai, 0x4A35582a710E1F4b2030A3F826DA20BfB6703C09, amtToDeposit, 0, 0);

    }

    function buildOnlyBlackAuth() public pure returns (string[] memory _targets, bytes[] memory _data) {

        // encoding data to run multiple things through cast on account
        // Depositing in DSA and then deposit in Compound through DSA.
        _targets = new string[](2);
        _data = new bytes[](2);
        
        _targets[0] = "BASIC-A";
        _targets[1] = "AUTHORITY-A";
        
        bytes4  basicDeposit = bytes4(keccak256("deposit(address,uint256,uint256,uint256)"));
        bytes4  auth = bytes4(keccak256("add(address)"));
        
        address dai = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
        uint amtToDeposit = 1e18; // 1 DAI

        _data[0] = abi.encodeWithSelector(basicDeposit, dai, amtToDeposit, 0, 0);
        // withdraw to not auth ext address
        _data[1] = abi.encodeWithSelector(auth, address(0));

    }

    function mergeBytes(bytes memory param1, bytes memory param2) public pure returns (bytes memory) {
        bytes memory merged = new bytes(param1.length + param2.length);
        uint k = 0;
        for (uint i = 0; i < param1.length; i++) {
            merged[k] = param1[i];
            k++;
        }
        for (uint i = 0; i < param2.length; i++) {
            merged[k] = param2[i];
            k++;
        }
        return merged;
    }

}
