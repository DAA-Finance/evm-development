# DAA Monorepo

Repository containing all contracts necessary for DAA Modules full setup. It includes:

-   Module 1 - DAA Withdrawal Module. 
    The module allows safe owner addresses to transfer tokens to a whitelisted address with a single transaction.
    https://github.com/vincfurc/gnosis-module-daa

-   Module 2 - DAA DSA Module. 
    Module to enable on a 3/4 safe that will permit 2/4 signers to do various actions on an instadapp DSA, but will prevent any changing of DSA authority or withdrawal to non-safe address.
    https://github.com/vincfurc/daa-dsa-module 

-   Setup Module - 
    Shell module allowing a Safe to deploy and initialize the DAA Modules.
    https://github.com/vincfurc/daa-monorepo/blob/main/src/contracts/SetupModule.flattened.sol 

# Resources

-   [Foundry Book](https://onbjerg.github.io/foundry-book/)
-   [Foundry Starter Kit](https://github.com/smartcontractkit/foundry-starter-kit)

# Quickstart

## Requirements

-   [Forge/Foundryup](https://github.com/gakonst/foundry#installation)
    -   You'll know you've done it right if you can run `forge --version`
-   [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
    -   You'll know you've done it right if you can run `git --version`

```
git clone https://github.com/vincfurc/daa-monorepo
cd foundry-play
foundryup
make

forge test --fork-url https://<polygon-rpc-url> -vvv 
```
