import eth_account
from eth_account import Account
from hexbytes import HexBytes
from web3 import Web3


def main():

    hex_message_hash = '0x5b7e129e8d3a005e8290aea64e4e97ebb46504f2735a31e3d2cba10b28c7d064'
    contract_transaction_hash = HexBytes(hex_message_hash)
    # example key
    account = Account.from_key('0x66e91912f68828c17ad3fee506b7580c4cd19c7946d450b4b0823ac73badc878')
    signature = account.signHash(contract_transaction_hash)
    hex_signature = signature.signature.hex()
    print('account: ', account.address)
    print('signature: ',signature.signature.hex())

    sig = Web3.toBytes(hexstr=hex_signature)
    v, hex_r, hex_s = Web3.toInt(sig[-1]), Web3.toHex(sig[:32]), Web3.toHex(sig[32:64])
    ec_recover_args = (hex_message_hash, v, hex_r, hex_s)
    print(ec_recover_args)