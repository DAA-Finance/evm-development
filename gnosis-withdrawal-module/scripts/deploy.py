from brownie import DaaModule, accounts, interface, config,chain



def main():

    # dev = accounts.at('',force=True)
    contract = DaaModule.deploy({'from': accounts[0]})

   
