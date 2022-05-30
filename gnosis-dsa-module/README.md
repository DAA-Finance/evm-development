# Daa Dsa Module

Module to enable on a 3/4 safe that will permit 2/4 signers to do various actions on an instadapp DSA, but will prevent any changing of DSA authority or withdrawal to non-safe address.

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
git clone https://github.com/vincfurc/repo
cd foundry-play
foundryup
make

forge test --fork-url https://<url> -vvv 
```
