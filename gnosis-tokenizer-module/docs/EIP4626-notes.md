# EIP 4626

The ERC4626 standardises the tokenization of single asset vaults (e.g. yUSDC). It takes the base asset as an input, together with the name and symbol of the tokenizer share.
The contract itself is an ERC20 (i.e. share token) and both base assets and share tokens can be used to interact with the contract.

 - deposit - here is exact assets, give me some shares
 - mint - give me exact shares, here is some assets
 - withdraw = give me exact assets, here is some shares
 - redeem = here is exact shares, give me some assets

The core methods of the ERC4626 are already implemented in the current tokeniser, and there are a few extra accounting functions which could be useful for future integrations. The fee calculation is accounted for but not built in, meaning that some methods will need to return values plus/minus fees, but the way to calculate the fees still need to be decided by the single vault implementation.

## Methods

-	Asset – it will be base asset
-	totalAssets – to implement, it will be NAV + fees
-	convertToShares – already present in pricePerShare, but need to add arbitrary quantity
-	convertToAssets – already present in calcBaseAsset
-	maxDeposit – there is no max (? to confirm) so must return 2 ** 256 – 1
-	previewDeposit – Not implemented - MUST be inclusive of deposit fees
-	deposit – current implementation allows for multi-asset deposit, need to restrict if made compliant
-	maxMint – to implement
-	previewMint – to implement
-	mint – to implement, differs from deposit by basically allowing the minting of  a specific number of shares
-	maxWithdraw – to implement
-	previewWithdraw – to implement, must be inclusive of withdrawal fees
-	withdraw – to implement, differs from redeem as it allows to specify exact assets to withdraw as input
-	maxRedeem – to implement
-	previewRedeem – to implement, inclusive of fees
-	redeem – already present as redeem

## Events

-	deposit – already present as depositReceived
-	withdraw – already present as withdrawal

## Rounding Guidelines

Finally, ERC-4626 Vault implementers should be aware of the need for specific, opposing rounding directions across the different mutable and view methods, as it is considered most secure to favor the Vault itself during calculations over its users:
•	If (1) it’s calculating how many shares to issue to a user for a certain amount of the underlying tokens they provide or (2) it’s determining the amount of the underlying tokens to transfer to them for returning a certain amount of shares, it should round down.
•	If (1) it’s calculating the amount of shares a user has to supply to receive a given amount of the underlying tokens or (2) it’s calculating the amount of underlying tokens a user has to provide to receive a certain amount of shares, it should round up.
The only functions where the preferred rounding direction would be ambiguous are the convertTo functions. To ensure consistency across all ERC-4626 Vault implementations it is specified that these functions MUST both always round down. Integrators may wish to mimic rounding up versions of these functions themselves, like by adding 1 wei to the result.
Although the convertTo functions should eliminate the need for any use of an ERC-4626 Vault’s decimals variable, it is still strongly recommended to mirror the underlying token’s decimals if at all possible, to eliminate possible sources of confusion and simplify integration across front-ends and for other off-chain users.

## References

https://eips.ethereum.org/EIPS/eip-4626

https://github.com/fei-protocol/ERC4626

https://github.com/Rari-Capital/solmate/blob/main/src/mixins/ERC4626.sol



