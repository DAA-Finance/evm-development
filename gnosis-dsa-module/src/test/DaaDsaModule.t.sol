// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "../contracts/DaaDsaModule.sol";
import "../interfaces/IERC20Minimal.sol";

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

contract DaaModuleTest is DSTest {

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

    CheatCodes constant cheats = CheatCodes(HEVM_ADDRESS);

    function setUp() public {
        daaDsaModule = new DaaDsaModule();
        daaDsaModule.initialize(IGnosisSafe(safeAddress),IInstaIndex(instaIndexAddress),137);
        //enable module
        cheats.prank(safeAddress);
        IGnosisSafe(safeAddress).enableModule(address(daaDsaModule));
        safeOwners = IGnosisSafe(safeAddress).getOwners();
    }

    /* ----------- TEST DSA ACCOUNT ------------ */

    function testAccountCreation() public {
        cheats.prank(safeOwners[0]); //safe owner
        daaDsaModule.createAccount(2,address(0));
    }

    function testFailAccountCreationFuzz(address sender) public {
        cheats.prank(sender); //safe owner
        daaDsaModule.createAccount(2,address(0));
    }

    function testAccountCreationWhenInit() public {
        cheats.prank(safeOwners[0]); //safe owner
        daaDsaModule.createAccount(2,address(0));
        cheats.prank(safeOwners[0]); //safe owner
        cheats.expectRevert(bytes("DSA already created"));
        daaDsaModule.createAccount(2,address(0));
    }

    function testChangeSafeOwner() public {
        address[] memory prevSafeOwners = IGnosisSafe(safeAddress).getOwners();
        address prevOwner = prevSafeOwners[1];
        cheats.prank(prevOwner);
        daaDsaModule.createAccount(2,address(0));
        cheats.prank(safeAddress);
        IGnosisSafe(safeAddress).removeOwner(prevSafeOwners[0],prevOwner,1);
        cheats.prank(prevOwner);
        cheats.expectRevert(bytes("Sender not authorized"));
        daaDsaModule.createAccount(2,address(0));
    }

    /* ----------- TEST SIGNATURES ------------ */

    function testSignatureOffChain() public {
        // EOA account that will sign the hash
        address signer = 0x6a2EB7F6734F4B79104A38Ad19F1c4311e5214c8;
        // get mock tx data
        (string[] memory targets, bytes[] memory data) = buildOnly();
        bytes32 hash = daaDsaModule.getTransactionHash(targets,data,0);
        // off chain sig import
        bytes memory sig = fromHex("a66f29205ca109f2bdcf0bf60aaec19b05ee9ab59eac1aecae9247276f6b297b5b4a935f1be87b43c4a90cf8c943f1a38261469db9e2d6ed2ae1d9256e3bccb51b");
        ( uint8 v, bytes32 r, bytes32 s) = signatureSplit(sig,0);
        assertTrue(v == 27);
        // emit log_uint(v); emit log_bytes32(r);  emit log_bytes32(s); 
        address recoveredSigner = ecrecover(hash,v,r,s);
        assertTrue(signer == recoveredSigner);
    }

    function testSignatureOnChain() public {
        address signer = safeOwners[0];
        // 65 bytes -> padded to 32, padded to 32, 01 (sig type) - (e.g. https://github.com/safe-global/safe-contracts/blob/v1.0.0/test/gnosisSafeTeamEdition.js) 
        bytes memory sig = mergeBytes(abi.encode(address(signer),0),abi.encodePacked(bytes1(uint8(1))));
        // emit log_bytes(sig); emit log_uint(sig.length);
        // emit log("v - r - s");
        ( uint8 v, bytes32 r, bytes32 s) = signatureSplit(sig, 0);
        // emit log_uint(v); emit log_bytes32(r);  emit log_bytes32(s);
        assertTrue(v == 1);
        assertTrue(keccak256(abi.encode(signer)) == keccak256(abi.encode(r)));
    }

    /* ----------- TEST DSA LOGIC ------------ */

    function testGetTransactionHash() public {
        // get mock tx data
        (string[] memory targets, bytes[] memory data) = buildOnly();
        bytes32 hash = daaDsaModule.getTransactionHash(targets,data,0);
        emit log_bytes32(hash);
    }

    function testForwarding() public {
        // DSA creation 
        address _account = instaIndex.build(address(this), 2, address(0)); // 2 is the most recent DSA version
        // get mock tx data
        (string[] memory targets, bytes[] memory data) = buildOnly();
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
        IDSA(_account).cast(targets, data, address(0)); // Magic!!
        // check amount is invested
        assertTrue(IERC20Minimal(tokenAddress[0]).balanceOf(address(this)) == 0);
        assertTrue(IERC20Minimal(tokenAddress[0]).balanceOf(_account) == 0);
    }

    /* ----------- TEST TX FILTERING ------------ */


    function testApproveHashFail(address sender) public {
        cheats.assume(sender != safeOwners[0] && sender != safeOwners[1]);
        cheats.prank(safeOwners[0]);
        daaDsaModule.createAccount(2,address(0));
        // get mock tx data
        (string[] memory targets, bytes[] memory data) = buildOnly();
        bytes32 hash = daaDsaModule.getTransactionHash(targets,data,0);
        cheats.prank(sender); //safe owner
        cheats.expectRevert(bytes("Sender not authorized"));
        daaDsaModule.approveHash(hash); 
    }

    function testApproveHashAddress0() public {
        address sender = address(0);
        cheats.prank(safeOwners[0]);
        daaDsaModule.createAccount(2,address(0));
        // get mock tx data
        (string[] memory targets, bytes[] memory data) = buildOnly();
        bytes32 hash = daaDsaModule.getTransactionHash(targets,data,0);
        cheats.prank(sender); //safe owner
        cheats.expectRevert(bytes("Sender not authorized"));
        daaDsaModule.approveHash(hash); 
    }

    function testBlacklistedWithdraw() public {
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
        // DSA creation 
        instaIndex.build(address(this), 2, address(0)); // 2 is the most recent DSA version
        // get mock tx data expected to Fail
        (string[] memory targets, bytes[] memory data) = buildOnlyBlackAuth();
        // mock logic of connector check - data digest
        // will fail and revert if no auth op
        cheats.expectRevert(bytes("NoAuth"));
        daaDsaModule.getConnectorData(targets, data);
    }   


    /* ----------- TEST EXECUTION ACCESS ------------ */

    function testExecution() public {
        address owner1 = safeOwners[0];
        address owner2 = safeOwners[1];

        cheats.prank(owner1);
        daaDsaModule.createAccount(2,address(0));
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

    function testExecutionBeforeThreshold() public {
        address owner = safeOwners[0];
        cheats.prank(owner);
        daaDsaModule.createAccount(2,address(0));
        // get mock tx data
        (string[] memory targets, bytes[] memory data) = buildOnly();
        bytes32 hash = daaDsaModule.getTransactionHash(targets,data,0);
        cheats.prank(owner); //safe owner
        daaDsaModule.approveHash(hash);
        // 65 bytes -> padded to 32, padded to 32, 01 (sig type) - (e.g. https://github.com/safe-global/safe-contracts/blob/v1.0.0/test/gnosisSafeTeamEdition.js) 
        bytes memory sig = mergeBytes(abi.encode(address(owner),0),abi.encodePacked(bytes1(uint8(1))));

        // safe balance before TX
        address dai = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
        uint amtToDeposit = 1e18; // 1 DAI
        assertTrue(IERC20Minimal(dai).balanceOf(safeAddress) == amtToDeposit);
        cheats.prank(owner); //safe owner
        cheats.expectRevert(bytes("GS020"));
        daaDsaModule.executeTransaction(targets,data,sig);
    }

    function testExecutionAddress0() public {
        address owner1 = safeOwners[0];
        address owner2 = address(0);
        cheats.prank(owner1);
        daaDsaModule.createAccount(2,address(0));
        // get mock tx data
        (string[] memory targets, bytes[] memory data) = buildOnly();
        bytes32 hash = daaDsaModule.getTransactionHash(targets,data,0);

        cheats.prank(owner1); //safe owner
        daaDsaModule.approveHash(hash);
        // 65 bytes -> padded to 32, padded to 32, 01 (sig type) - (e.g. https://github.com/safe-global/safe-contracts/blob/v1.0.0/test/gnosisSafeTeamEdition.js) 
        bytes memory sig1 = mergeBytes(abi.encode(address(owner1),0),abi.encodePacked(bytes1(uint8(1))));
        bytes memory sig2 = mergeBytes(abi.encode(address(owner2),0),abi.encodePacked(bytes1(uint8(1))));
        
        bytes memory sigs = abi.encodePacked(sig1,sig2);
        // emit log_bytes(sigs);

        // safe balance before TX
        address dai = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
        uint amtToDeposit = 1e18; // 1 DAI
        assertTrue(IERC20Minimal(dai).balanceOf(safeAddress) == amtToDeposit);
        cheats.prank(owner1); //safe owner
        cheats.expectRevert(bytes("GS025"));
        daaDsaModule.executeTransaction(targets,data,sigs);
    }

    function testExecutionOneInFail(address owner2) public {
        cheats.assume(owner2 != safeOwners[0] && owner2 != safeOwners[1]);
        address owner1 = safeOwners[0];
        cheats.prank(owner1);
        daaDsaModule.createAccount(2,address(0));
        // get mock tx data
        (string[] memory targets, bytes[] memory data) = buildOnly();
        bytes32 hash = daaDsaModule.getTransactionHash(targets,data,0);

        cheats.prank(owner1); //safe owner
        daaDsaModule.approveHash(hash);
        // 65 bytes -> padded to 32, padded to 32, 01 (sig type) - (e.g. https://github.com/safe-global/safe-contracts/blob/v1.0.0/test/gnosisSafeTeamEdition.js) 
        bytes memory sig1 = mergeBytes(abi.encode(address(owner1),0),abi.encodePacked(bytes1(uint8(1))));
        bytes memory sig2 = mergeBytes(abi.encode(address(owner2),0),abi.encodePacked(bytes1(uint8(1))));
        
        bytes memory sigs = abi.encodePacked(sig1,sig2);
        // emit log_bytes(sigs);

        // safe balance before TX
        address dai = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
        uint amtToDeposit = 1e18; // 1 DAI
        assertTrue(IERC20Minimal(dai).balanceOf(safeAddress) == amtToDeposit);
        cheats.prank(owner1); //safe owner
        cheats.expectRevert(bytes("GS025"));
        daaDsaModule.executeTransaction(targets,data,sigs);
    }

    function testExecutionZeroInFail(address owner1, address owner2) public {
        cheats.assume(owner1 != safeOwners[0] && owner1 != safeOwners[1]);
        cheats.assume(owner2 != safeOwners[0] && owner2 != safeOwners[1]);

        cheats.prank(safeOwners[0]); // let create account - testing execution not creation
        daaDsaModule.createAccount(2,address(0));
        // get mock tx data
        (string[] memory targets, bytes[] memory data) = buildOnly();

        // 65 bytes -> padded to 32, padded to 32, 01 (sig type) - (e.g. https://github.com/safe-global/safe-contracts/blob/v1.0.0/test/gnosisSafeTeamEdition.js) 
        bytes memory sig1 = mergeBytes(abi.encode(address(owner1),0),abi.encodePacked(bytes1(uint8(1))));
        bytes memory sig2 = mergeBytes(abi.encode(address(owner2),0),abi.encodePacked(bytes1(uint8(1))));
        
        bytes memory sigs = abi.encodePacked(sig1,sig2);
        // emit log_bytes(sigs);

        // safe balance before TX
        address dai = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
        uint amtToDeposit = 1e18; // 1 DAI
        assertTrue(IERC20Minimal(dai).balanceOf(safeAddress) == amtToDeposit);
        cheats.prank(owner1); //safe owner
        cheats.expectRevert(bytes("Sender not authorized"));
        daaDsaModule.executeTransaction(targets,data,sigs);
    }

    function testExecutionDoubleFail() public {
        address owner1 = safeOwners[0];
        address owner2 = safeOwners[1];

        cheats.prank(owner1);
        daaDsaModule.createAccount(2,address(0));
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
        // try second time with valid sig
        cheats.prank(owner1);
        cheats.expectRevert(bytes("GS025")); // should fail in checkNsignatures
        daaDsaModule.executeTransaction(targets,data,sigs);
    }

    /* ----------- UTILS ------------ */

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

    function buildOnlyArbitraryAmt(uint amtToDeposit) public returns (string[] memory _targets, bytes[] memory _data) {

        // encoding data to run multiple things through cast on account
        // Depositing in DSA and then deposit in Compound through DSA.
        _targets = new string[](2);
        _data = new bytes[](2);
        
        _targets[0] = "BASIC-A";
        _targets[1] = "AAVE-V2-A";
        
        bytes4  basicDeposit = bytes4(keccak256("deposit(address,uint256,uint256,uint256)"));
        bytes4  aaveDeposit = bytes4(keccak256("deposit(address,uint256,uint256,uint256)"));
        
        address dai = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
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

    function buildAndCast() public returns (string[] memory _targets, bytes[] memory _data) {

        // creating an account
        address _account = instaIndex.build(address(this), 2, address(0)); // 2 is the most recent DSA version
        
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
        // get some DAI from a random DAI-full address
        cheats.prank(0x4A35582a710E1F4b2030A3F826DA20BfB6703C09);
        IERC20Minimal(dai).transfer(address(this),amtToDeposit);


        _data[0] = abi.encodeWithSelector(basicDeposit, dai, amtToDeposit, 0, 0);
        _data[1] = abi.encodeWithSelector(aaveDeposit, dai, amtToDeposit, 0, 0);
        
        IERC20Minimal(dai).approve(_account,amtToDeposit);
        
        IDSA(_account).cast(_targets, _data, address(0)); // Magic!!
    }

    function signatureSplit(bytes memory signatures, uint256 pos)
        public
        pure
        returns (
            uint8 v,
            bytes32 r,
            bytes32 s
        )
    {
        // The signature format is a compact form of:
        //   {bytes32 r}{bytes32 s}{uint8 v}
        // Compact means, uint8 is not padded to 32 bytes.
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let signaturePos := mul(0x41, pos)
            r := mload(add(signatures, add(signaturePos, 0x20)))
            s := mload(add(signatures, add(signaturePos, 0x40)))
            // Here we are loading the last 32 bytes, including 31 bytes
            // of 's'. There is no 'mload8' to do this.
            //
            // 'byte' is not working due to the Solidity parser, so lets
            // use the second best option, 'and'
            v := and(mload(add(signatures, add(signaturePos, 0x41))), 0xff)
        }
    }

    function stringToBytes32(string memory source) public pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            result := mload(add(source, 32))
        }
    }

    function toBytes(bytes32 _data) public pure returns (bytes memory) {
        return abi.encodePacked(_data);
    }

    // Convert an hexadecimal character to their value
    function fromHexChar(uint8 c) public pure returns (uint8) {
        if (bytes1(c) >= bytes1('0') && bytes1(c) <= bytes1('9')) {
            return c - uint8(bytes1('0'));
        }
        if (bytes1(c) >= bytes1('a') && bytes1(c) <= bytes1('f')) {
            return 10 + c - uint8(bytes1('a'));
        }
        if (bytes1(c) >= bytes1('A') && bytes1(c) <= bytes1('F')) {
            return 10 + c - uint8(bytes1('A'));
        }
    }

    // Convert an hexadecimal string to raw bytes
    function fromHex(string memory s) public pure returns (bytes memory) {
        bytes memory ss = bytes(s);
        require(ss.length%2 == 0); // length must be even
        bytes memory r = new bytes(ss.length/2);
        for (uint i=0; i<ss.length/2; ++i) {
            r[i] = bytes1(fromHexChar(uint8(ss[2*i])) * 16 +
                        fromHexChar(uint8(ss[2*i+1])));
        }
        return r;
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

    // slither src/contracts/flattened/DaaDsaModuleFlat.sol solc-select use 0.8.13
}
