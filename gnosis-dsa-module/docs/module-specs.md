# DAA DSA Module

### Module Description 

Module to enable on a 3/4 safe that will permit 2/4 signers to do various actions on an instadapp DSA but will prevent any changing of DSA authority or withdrawal to non-safe address.

### How the DSA works

Instadapp allows to deploy a DeFi Smart Account (DSA) contract, which will be the only contract with which the user will interact with.

To simulate a transaction in Module 1, the user interacts with their smart account using the cast() function. This is the core function that allows smart accounts to interact with DeFi protocols and complete composable transactions.

However, the cast function does not reside in the smart account contract of the user, hence the fallback function is called to get the implementation contract using msg.sig.

The DSA contract uses a fallback function to fetch the address of the Extension Module to call via Implementation - contract using (msg.sig) of the function called by the user. 

After getting the extension contract, a delegate call is made to the respective extension which contains the cast function to run all the spells.

Inside the spell function, delegate call(s) is done to execute the function called by the user.

### How the Module relates to the DSA

The DSA get called upon through the cast() function. 
The cast function to the DSA has encoded input data containing details about the transaction (e.g. deposit 100eth to Compound). This data gets passed through the instaAccount and the instaImplementation which decode it to identify which function has been called and to what connector (e.g. Compund contract) to send it. 
Therefore, the inputs to the cast function contain all relevant information necessary to filter out unwanted operations.

The module implementation will decode the calldata and identify what function is the target of the transaction. 
In this way, the module should identify the Authority functions and the external Withdraw function as reliably as the DSA itself. The module will ultimately use a require() condition on the execute() function of the module to block the blacklisted operations. 

## Specification

### Methods

createAccount

    Wrapper around the DSA Build() function, used to create the DSA with the module as owner address.

    MUST store in storage the newly built DSA account, which will be used as a recepient for transactions.

    Emits an AccountCreated event.

    -   name: createAccount
        type: function
        stateMutability: nonpayable

        inputs:
        -   name: accountVersion
            type: uint
        -   name: accountOrigin
            type: address

        outputs:
        -   name: newAccount
            type: address

executeTransaction 

    Allows to execute transactions to a DSA contract, as a wrapper around the DSA cast() function.

    MUST blacklist Authority targets and Withdraw target when to an external non-module address.

    MUST check that at least 2 Safe owner signatures have approved the transaction.

    MUST increase the module transaction nonce.

    Emits a TransactionExecuted event.

    -   name: executeTransaction
        type: function
        stateMutability: payable

        inputs:
        -   name: _targetNames
            type: string[] calldata
        -   name: _datas
            type: bytes[] calldata
        -   name: signatures
            type: bytes memory

        outputs: []


getConnectorData

    Allows to decode the transaction data for safety checks, and to prepare the token amount to be pulled from the Safe.

    inputs:
        -   name: connectorId
            type: string
        -   name: data
            type: bytes calldata
    
    outputs:
        -   name: addrList
            type: address[] //of the token to transfer
        -   name: amtList
            type: uint[] //respective amounts


pullFromSafe

    Leverage the Safe module functionaliity to pull the tokens required for the DSA transaction.

    inputs:
        -   name: token
            type: address
        -   name: amount
            type: uint

    outputs:[]


checkSignatures

    Checks whether the signature provided is valid for the provided data, hash. Will revert otherwise.

    -   name: checkSignatures
        type: function
        stateMutability: view

        inputs:
        -   name: dataHash
            type: bytes32
        -   name: data
            type: bytes memory
        -   name: signatures
            type: bytes memory
        
        outputs: []

approveHash

    Marks a hash as approved. This can be used to validate a hash that is used by a signature.
    
    Emits an ApprovedHash event.

    -   name: approveHash
        type: function
        stateMutability: nonpayable

        inputs: 
        -   name: hashToApprove
            type: bytes32
        
        outputs: []
        
getTransactionHash

    Returns hash to be signed by owners.

    -   name: getTransactionHash
        type: function
        stateMutability: view

        inputs:
        -   name: _targetNames
            type: string[] calldata
        -   name: _datas
            type: bytes[] calldata
        -   name: nonce
            type: uint256

        outputs: []





### Events
AccountCreated

MUST be emitted when a DSA account is created for the module via the createAccount method.

    -   name: AccountCreated
        type: event

        inputs:    
        -   name: dsaAccount
            type: address
        -   name: version
            type: uint  
        -   name: creator
            type: address  


TransactionExecuted

MUST be emitted when a transaction to the DSA is executed via the executeTransaction method.

    -   name: TransactionExecuted
        type: event

        inputs: 
        -   name: txHash
        -   type: bytes32

ApproveHash

MUST be emitted when a Safe owner signs a transaction via the approveHash method.

    -   name: ApproveHash
        type: event

        inputs:
        -   name: hash
            type: bytes32
        -   name: txNonce
            type: uint
        -   name: approver
            type: address


### Security Considerations

Once funds are transferred from the module to the DSA, they inevitably inherit the security of instadapp DSL. 
A vulnerability in the DSL could potentially cause loss of funds already transferred to the DSA account.


### References

https://docs.instadapp.io/

https://github.com/gnosis/safe-contracts/blob/main/contracts/GnosisSafe.sol 