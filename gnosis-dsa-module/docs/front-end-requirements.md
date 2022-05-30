# DAA DSA Module - Front-End Guide

### Introduction 

The Instadapp protocol ('DSL') acts as the middleware that aggregates multiple DeFi protocols into one smart contract layer.


A "spell" denotes a sequence of function calls that achieves a particular use case. Performing DeFi operations through Instadapp consists of creating a Spell instance to add transactions, and then executing it through a cast() method. 


### Requirements 

The Module smart contract will need to receive transaction data from the front-end in order to execute  transactions on its DSA.

In their raw form, transaction data will include:

    1) Connector ID - the identifier for the DeFi protocol connector (e.g. "COMPOUND-A")
    2) Method - the method to execute for the specific connector (e.g. "deposit")
    3) Args - the arguments required for the various methods in connectors (e.g. ["USDC-A" "1000000", 0, 0,])

These three inputs will need to be fetched from the user interaction with the UI. For instance, a user could generate the example data from the above bullet points by selecting 1 USDC token and clicking a Supply button on the Compound protocol section of the UI.


#### Instadapp SDK

Instadapp provides an official [instadapp SDK](https://github.com/Instadapp/dsa-connect/) to facilitate the interaction with the smart contracts.

The SDK requires the same three inputs above to create a Spell. However, before submitting these inputs for a transaction, they need to be encoded in a format digestibile by the Instadapp smart contracts.

The SDK abstracts the encoding of these transaction data inputs while performing the [cast()](https://docs.instadapp.io/get-started/cast) method. The front-end will then ask users to confirm the transaction on web3 wallet like Metamask, and the transaction would be submitted to the blockchain. 

Since the DAA Module is a smart contract and cannot execute transactions through Metamask, the SDK cannot be leveraged to send transactions to the Module DSA in a straighforward way. An easy alterantive would be to collect the three inputs (as for the SDK), perform the encoding, and let the user submit the transaction to the Module with the encoded data as calldata.

#### Workflow

The workflow to generate the inputs required by the DAA Module smart contract is the following:

1) Associate each UI protocol button with the corresponding connector and connector inputs (see all available connectors [here](https://docs.instadapp.io/connectors/polygon)).
2) Users interact with the UI to generate transaction data inputs (i.e., connector ID, method, args).
3) The transaction data is encoded prior to the transaction being sent. 

Encoding

    inputs:
    -   name: connectorID
        type: string
    -   name: method
        type: string
    -   name: args
        type: array:any

    outputs:
    -   name: targets
        type: array:string
    -   name: data
        type: bytes

Output variable `targets` is an array of all connectorIDs strings for a transaction (e.g. for a transaction composed by two actions["BASIC-A", "COMPOUND-A"]). 
Output variable`data` is an array containing the abi encoded data for each action of the transaction. It is obtained in two steps:

    1) Get method selector by grabbing the first 4 bytes of the hashed method
          bytes4  aaveDeposit = bytes4(keccak256("deposit(address,uint256,uint256,uint256)"));
    2) Encode the method selector with the arguments value
          data[0] = abi.encodeWithSelector(aaveDeposit, dai, amtToDeposit, 0, 0);

        
4) The last step requires prompting the user to authorize and submit the transaction via Metamask:

Web3.js

    submitTransaction = (_targets, _data) => {
    moduleContract.methods.executeTransaction(_targets, _data).send({ from: account })

### References

https://github.com/Instadapp/dsa-connect/ 

https://docs.instadapp.io/