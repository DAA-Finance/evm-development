// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

import "./utils/Enum.sol";
import "./utils/SignatureDecoder.sol";
import "./utils/CompatibilityFallbackHandler.sol";
import "../interfaces/IERC20Minimal.sol";
import "../interfaces/ISignatureValidator.sol";
import "../interfaces/IGnosisSafe.sol";


/// @title DAA DSA Module - A gnosis safe module to execute whitelisted transactions to a DSA.


interface IInstaIndex {
    function build(
        address _owner,
        uint256 _accountVersion,
        address _origin
    ) external returns (address _account);
}

interface IDSA {
    function cast(
        string[] calldata _targetNames,
        bytes[] calldata _datas,
        address _origin
    ) external payable returns (bytes32);
}


contract DaaDsaModule is 
    SignatureDecoder,
    ISignatureValidator,
    CompatibilityFallbackHandler
{

    IGnosisSafe public safe;
    IDSA public account;
    IInstaIndex instaIndex; 
    address native = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE; // format polygon specific
    uint256 public nonce;

    uint256 internal threshold = 2;

    string public constant name = "DAA Module";
    string public constant version  = "1";
    bool public initialized;

    // --- EIP712 ---
    bytes32 public DOMAIN_SEPARATOR;
    // bytes32 private constant MODULE_TX_TYPEHASH = keccak256("ModuleTx(string[] calldata _targetNames, string[] calldata _datas, uint256 _nonce)");
    bytes32 private constant MODULE_TX_TYPEHASH = 0x70f96b20d0f94e90121e640b822abdfe2918aa3b37ed19df9ac632a914413cbf;

    // Mapping to keep track of all hashes (message or transaction) that have been approved by ANY owners
    mapping(address => mapping(bytes32 => uint256)) public approvedHashes;


    event AccountCreated(address dsaAccount, uint version, address creator);
    event ApproveHash(bytes32 indexed approvedHash, address indexed owner);
    event TransactionExecuted(bytes32 txHash);

    constructor(){}

    /// @dev Create a DSA account for the module.
    /// @param _safe Safe address.
    /// @param _index Index address of Instadapp.
    /// @param _chainId The chain id for multi-chain deployments.
    function initialize(IGnosisSafe _safe, IInstaIndex _index, uint256 _chainId) external {
        require(!initialized, "Already initialized"); 
        safe = _safe;
        instaIndex = IInstaIndex(_index); 
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes(name)),
            keccak256(bytes(version)),
            _chainId,
            address(this)
        ));
        initialized = true;
    }

    /// @dev Execute transaction on DSA.
    /// @param _targetNames DSA transaction target names.
    /// @param _datas DSA transaction data.
    /// @param signatures The bytes encoded signatures approving the tx.
    function executeTransaction(
        string[] calldata _targetNames,
        bytes[] calldata _datas,
        bytes memory signatures
    ) 
        external
    {
        require(isAuthorized(msg.sender));
        require(address(account) != address(0), "DSA not created");
        bytes32 txHash;
        bytes memory txHashData =
            encodeTransactionData(
                _targetNames,
                _datas,
                nonce
            );
        txHash = getTransactionHash(_targetNames,_datas,nonce);
        // Increase nonce and prep transaction.
        nonce++;
        checkSignatures(txHash, txHashData, signatures);
        (address[] memory  tokenAddress, uint[] memory amount) = this.getConnectorData(_targetNames, _datas);
        prepFunds(tokenAddress, amount);
        // execute transaction
        execute(_targetNames,_datas);
        emit TransactionExecuted(txHash);
    }

    /// @dev Checks whether the signature provided is valid for the provided data, hash. Will revert otherwise.
    /// @param dataHash Hash of the data (could be either a message hash or transaction hash)
    /// @param data That should be signed (this is passed to an external validator contract)
    /// @param signatures Signature data that should be verified. Can be ECDSA signature, contract signature (EIP-1271) or approved hash.
    function checkSignatures(
        bytes32 dataHash,
        bytes memory data,
        bytes memory signatures
    ) public view {
        // Load threshold to avoid multiple storage loads
        uint256 _threshold = threshold;
        // Check that a threshold is set
        require(_threshold > 0, "Threshold not set.");
        checkNSignatures(dataHash, data, signatures, _threshold);
    }

    /// @dev Checks whether the signature provided is valid for the provided data, hash. Will revert otherwise.
    /// @param dataHash Hash of the data (could be either a message hash or transaction hash)
    /// @param data That should be signed (this is passed to an external validator contract)
    /// @param signatures Signature data that should be verified. Can be ECDSA signature, contract signature (EIP-1271) or approved hash.
    /// @param requiredSignatures Amount of required valid signatures.
    function checkNSignatures(
        bytes32 dataHash,
        bytes memory data,
        bytes memory signatures,
        uint256 requiredSignatures
    ) public view {
        // Check that the provided signature data is not too short
        require(signatures.length >= requiredSignatures*65, "GS020");
        // There cannot be an owner with address 0.
        address lastOwner = address(0);
        address currentOwner;
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 i;
        for (i = 0; i < requiredSignatures; i++) {
            (v, r, s) = signatureSplit(signatures, i);
            if (v == 0) {
                // If v is 0 then it is a contract signature
                // When handling contract signatures the address of the contract is encoded into r
                currentOwner = address(uint160(uint256(r)));

                // Check that signature data pointer (s) is not pointing inside the static part of the signatures bytes
                // This check is not completely accurate, since it is possible that more signatures than the threshold are send.
                // Here we only check that the pointer is not pointing inside the part that is being processed
                require(uint256(s) >= requiredSignatures*65, "GS021");

                // Check that signature data pointer (s) is in bounds (points to the length of data -> 32 bytes)
                require(uint256(s)+(32) <= signatures.length, "GS022");

                // Check if the contract signature is in bounds: start of data is s + 32 and end is start + signature length
                uint256 contractSignatureLen;
                // solhint-disable-next-line no-inline-assembly
                assembly {
                    contractSignatureLen := mload(add(add(signatures, s), 0x20))
                }
                require(uint256(s)+(32)+(contractSignatureLen) <= signatures.length, "GS023");

                // Check signature
                bytes memory contractSignature;
                // solhint-disable-next-line no-inline-assembly
                assembly {
                    // The signature data for contract signatures is appended to the concatenated signatures and the offset is stored in s
                    contractSignature := add(add(signatures, s), 0x20)
                }
                require(ISignatureValidator(currentOwner).isValidSignature(data, contractSignature) == EIP1271_MAGIC_VALUE, "GS024");
            } else if (v == 1) {
                // If v is 1 then it is an approved hash
                // When handling approved hashes the address of the approver is encoded into r
                currentOwner = address(uint160(uint256(r)));
                // Hashes are automatically approved by the sender of the message or when they have been pre-approved via a separate transaction
                require(msg.sender == currentOwner || approvedHashes[currentOwner][dataHash] != 0, "GS025");
            } else if (v > 30) {
                // If v > 30 then default va (27,28) has been adjusted for eth_sign flow
                // To support eth_sign and similar we adjust v and hash the messageHash with the Ethereum message prefix before applying ecrecover
                currentOwner = ecrecover(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", dataHash)), v - 4, r, s);
            } else {
                // Default is the ecrecover flow with the provided data hash
                // Use ecrecover with the messageHash for EOA signatures
                currentOwner = ecrecover(dataHash, v, r, s);
            }
            require(currentOwner > lastOwner && isAuthorized(currentOwner) && currentOwner != address(0x1), "GS026");
            lastOwner = currentOwner;
        }
    }

    /// @dev Returns hash to be signed by owners.
    /// @param _targetNames DSA transaction target names.
    /// @param _datas DSA transaction data.
    /// @param _nonce Transaction nonce.
    function getTransactionHash(
        string[] calldata _targetNames,
        bytes[] calldata _datas,
        uint256 _nonce
    ) 
        public 
        view 
        returns (bytes32) 
    {
        return keccak256(abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        MODULE_TX_TYPEHASH,
                        unpackStrings(_targetNames),
                        unpackBytes(_datas),
                        _nonce))
                ));
    }

    /// @dev Returns the bytes that are hashed to be signed by owners.
    /// @param _targetNames DSA transaction target names.
    /// @param _datas DSA transaction data.
    /// @param _nonce Transaction nonce.
    function encodeTransactionData(
        string[] calldata _targetNames,
        bytes[] calldata _datas,
        uint256 _nonce
    ) 
        public 
        view 
        returns (bytes memory) 
    {
        return abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        MODULE_TX_TYPEHASH,
                        unpackStrings(_targetNames),
                        unpackBytes(_datas),
                        _nonce))
                );
    }

    function domainSeparator() public view returns (bytes32) {
        return DOMAIN_SEPARATOR;
    }

    /// @dev Create a DSA account for the module.
    /// @param accountVersion The version of the DSA account, 2 is the most recent DSA version.
    /// @param accountOrigin Address(0) as default.
    function createAccount(uint accountVersion, address accountOrigin)
        external 
        returns (IDSA) 
    {
        require(isAuthorized(msg.sender));
        require(address(account) == address(0), "DSA already created");
        address dsa = instaIndex.build(address(this), accountVersion, accountOrigin); 
        account = IDSA(dsa);
        emit AccountCreated(address(account), accountVersion, accountOrigin);
        return account;
    }

    /// @dev Marks a hash as approved. This can be used to validate a hash that is used by a signature.
    /// @param hashToApprove The hash that should be marked as approved for signatures that are verified by this contract.
    function approveHash(bytes32 hashToApprove) 
        external 
    {
        require(isAuthorized(msg.sender));
        approvedHashes[msg.sender][hashToApprove] = 1;
        emit ApproveHash(hashToApprove, msg.sender);
    }

    /// @dev Allows to decode the transaction data for safety checks, and to prepare the token amount to be pulled from the Safe. 
    /// @param connectorId Connector identifier as for DSA docs.
    /// @param data Contains the transaction data to be digested by the DSA.
    function getConnectorData(string[] memory connectorId, bytes[] calldata data) public view returns (address[] memory addrList, uint[] memory amtList) {
        uint len = data.length;
        addrList = new address[](len);
        amtList = new uint[](len);
        for (uint i = 0; i < len; i++){
            whitelistedOpCheck(connectorId[i]);
            if (keccak256(abi.encodePacked(connectorId[i])) == keccak256("BASIC-A")){
                if (bytes4(data[i][:4]) == bytes4(keccak256("deposit(address,uint256,uint256,uint256)"))){
                    (address a, uint b, , ) = abi.decode(data[i][4:], (address, uint, uint, uint));
                    addrList[i] = a;
                    amtList[i] = b;
                } else if (bytes4(data[i][:4]) == bytes4(keccak256("withdraw(address,uint256,address,uint256,uint256)"))){
                    ( , , address to, , ) = abi.decode(data[i][4:], (address, uint,address, uint, uint));
                    addrList[i] = address(0);
                    amtList[i] = 0;
                    require(to == address(safe),"NoExt");
                }
            } else {
                // will get filtered out as amt = 0
                addrList[i] = address(0);
                amtList[i] = 0;
            }
        }
    }

    function prepFunds(address[] memory  tokenAddress, uint[] memory amount) internal {
        uint len = tokenAddress.length;
        for (uint i=0; i < len; i++){
            if (amount[i] > 0){
                pullFromSafe(tokenAddress[i],amount[i]);
                IERC20Minimal(tokenAddress[i]).approve(address(account),amount[i]);
            }
        }
    }

    function whitelistedOpCheck(string memory connectorId) internal pure {
        require(keccak256(abi.encodePacked(connectorId)) != keccak256(abi.encodePacked("AUTHORITY-A")),"NoAuth");
    }

    /// @dev Leverage the Safe module functionaliity to pull the tokens required for the DSA transaction.
    /// @param token Address of the token to transfer.
    /// @param amount Number of tokens,
    function pullFromSafe(address token, uint amount) private {
        if (token == native) {
            // solium-disable-next-line security/no-send
            require(safe.execTransactionFromModule(address(this), amount, "", Enum.Operation.Call), "Could not execute ether transfer");
        } else {
            bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", address(this), amount);
            require(safe.execTransactionFromModule(token, 0, data, Enum.Operation.Call), "Could not execute token transfer");
        }
    }

    function execute(string[] memory _targets, bytes[] memory _data) private {
        IDSA(account).cast(_targets, _data, address(0));
    }

    function unpackBytes(bytes[] memory data) internal pure returns (bytes memory unrolled){
        uint len = data.length;
        for (uint i=0; i < len; i++){
            unrolled = abi.encodePacked(unrolled, data[i]);
        }
    }

    function unpackStrings(string[] memory targets) internal pure returns (bytes memory unrolled){
        uint len = targets.length;
        for (uint i=0; i < len; i++){
            unrolled = abi.encodePacked(unrolled, targets[i]);
        }
    }

    function isAuthorized(address sender) internal view returns (bool isOwner){
        address[] memory _owners = safe.getOwners();
        uint256 len = _owners.length;
        for (uint256 i = 0; i < len; i++) {
            if (_owners[i]==sender) { isOwner = true;}
        }
        require(isOwner, "Sender not authorized");
    }
}
