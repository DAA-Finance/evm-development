# Gnosis Safe Daa Module

Once enabled, the module allows safe owner addresses to transfer tokens to a whitelisted address with a single transaction.
- The whitelisted address is initialised at deployment
- Any payable address can be the whitelisted address
- The whitelisted address is not modifiable
- Only safe owners addresses are authorized to send transactions (no delegates, no external addresses (with owners signatures) submitting transactions)
- The authorized addresses correspond to the safe owner addresses at the time of the transaction
- Only Ether and ERC20 token transfers allowed

## Prerequisites

Please install or have installed the following:

- [nodejs and npm](https://nodejs.org/en/download/)
- [python](https://www.python.org/downloads/)
## Installation

1. [Install Brownie](https://eth-brownie.readthedocs.io/en/stable/install.html), if you haven't already. Here is a simple way to install brownie.


```bash
python3 -m pip install --user pipx
python3 -m pipx ensurepath
# restart your terminal
pipx install eth-brownie
```
Or, if that doesn't work, via pip
```bash
pip install eth-brownie
```
## Local Development

For local testing [install ganache-cli](https://www.npmjs.com/package/ganache-cli)
```bash
npm install -g ganache-cli
```
or
```bash
yarn add global ganache-cli
```

## Testnet Development
If you want to be able to deploy to testnets, do the following.

Set your `WEB3_INFURA_PROJECT_ID`, and `ETHERSCAN_TOKEN`.

You can get a `WEB3_INFURA_PROJECT_ID` by getting a free trial of [Infura](https://infura.io/). At the moment, it does need to be infura with brownie. If you get lost, you can [follow this guide](https://ethereumico.io/knowledge-base/infura-api-key-guide/) to getting a project key.
You can get a `ETHERSCAN_TOKEN` by registering at [Etherscan](etherscan.io/).
You could also set your `PRIVATE_KEY`, which you can find from your ethereum wallet like [metamask](https://metamask.io/).

- Run Tests on Mainnet forked network:
`brownie test --network mainnet-fork`
