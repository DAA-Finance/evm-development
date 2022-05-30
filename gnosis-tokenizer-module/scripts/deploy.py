from brownie import Contract,DaaModule,ProxyHandler, OracleHandler,AaveConnector,PositionManager,TokenizedShare,accounts, interface, config,chain



def main():

    # # # # #

    aaveConnector = AaveConnector.at("0x1D693760969fd5cafe8E2524A0eAc4f05a36B361")
    positionManager = PositionManager.at("0xf128e2ca9acdd76295352bb59b3dfdd800cb293e")
    tokenizedShare = TokenizedShare.at('0x29EcEEea49caAB224C122c68CD83588e3740aBb3')
    # oracleHandler = OracleHandler.at('')
    # daaModule = DaaModule.at('0x8Cc6841Ce54d3614F5713e3c4b4e1A442012f81e')
    
    # # # # #

    dev = accounts.from_mnemonic(config["wallets"]["from_mnemonic"])
    # # aaveConnector = AaveConnector.at("0x1D693760969fd5cafe8E2524A0eAc4f05a36B361")
    # # AaveConnector.publish_source(aaveConnector)
    # aaveConnector = AaveConnector.deploy({'from': dev}, publish_source=True)
    # positionManager = PositionManager.deploy("0x213997398DdD5BBd98309428fa3Ae017D5570603", ["AAVE"],[aaveConnector], {'from': dev}, publish_source=True)
    daaModule = DaaModule.deploy( {'from': dev})
    # daaModule.initialize("0x213997398DdD5BBd98309428fa3Ae017D5570603",{'from': dev})
    # # tokenizedShare = TokenizedShare.deploy(daaModule,{'from': dev})
    # gnosisSafe =interface.GnosisSafe('0x213997398DdD5BBd98309428fa3Ae017D5570603')
    oracleHandler = OracleHandler.deploy({'from': dev})
    
    # tokenizedShare.mintInitialSupply(gnosisSafe,{"from": dev})
    proxy = ProxyHandler.deploy(daaModule.address,{'from': dev})
    proxyModule = Contract.from_abi("DaaModule", proxy.address, DaaModule.abi)
    assert(proxyModule.initialized() == False)
    proxyModule.initialize("0x213997398DdD5BBd98309428fa3Ae017D5570603",{'from': dev})
    assert(proxyModule.initialized() == True)
    assert(proxyModule.owner() == dev)
    proxyModule.setPositionManager(positionManager,{'from': dev})
    proxyModule.setTokenizedShare(tokenizedShare,{'from': dev})
    proxyModule.setOracleHandler(oracleHandler,{'from': dev})
    print(proxyModule.calculateNav())
    print(proxyModule.getTotalSharesOutstanding() )
    print(proxyModule.getPricePerShare())
    
    print("Set up complete, module deployed at: {}".format(daaModule.address))
    