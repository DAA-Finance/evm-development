from brownie import accounts, interface, Contract, ProxyHandler,DaaTokenizer, chain
from brownie.test import given, strategy
import pytest, math


# @given(amount=strategy('uint256', max_value=10**18))

###############

# get usdc polygon
@pytest.fixture(scope="session")
def usdc(interface):
    yield interface.IERC20Minimal('0x2791bca1f2de4661ed88a30c99a7a9449aa84174')

# get weth polygon
@pytest.fixture(scope="session")
def weth(interface):
    yield interface.IERC20Minimal('0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619')

# get random safe
@pytest.fixture(scope="session")
def gnosisSafe(interface):
    yield interface.GnosisSafe('0x933966159085a669279025283A6d250B505f4E8C') 
    # empty safe: 0x933966159085a669279025283A6d250B505f4E8C
    # filled safe: 0x213997398DdD5BBd98309428fa3Ae017D5570603

@pytest.fixture(scope="module")
def aaveConnector(AaveConnector, accounts):
    yield AaveConnector.deploy({'from': accounts[0]})

@pytest.fixture(scope="module")
def positionManager(aaveConnector,PositionManager, accounts):
    yield PositionManager.deploy("0x933966159085a669279025283A6d250B505f4E8C", ["AAVE"],[aaveConnector], {'from': accounts[0]})

@pytest.fixture(scope="module")
def daaTokenizer(DaaTokenizer,accounts):
    return DaaTokenizer.deploy({'from': accounts[0]})

@pytest.fixture(scope="module")
def tokenizedShare(TokenizedShare, daaTokenizer,accounts):
    return TokenizedShare.deploy(daaTokenizer,{'from': accounts[0]})

@pytest.fixture(scope="module")
def oracleHandler(OracleHandler,accounts):
    return OracleHandler.deploy({'from': accounts[0]})

@pytest.fixture(autouse=True)
def def_setters(daaTokenizer, positionManager,tokenizedShare,oracleHandler,accounts):
    # set contracts
    daaTokenizer.initialize("0x933966159085a669279025283A6d250B505f4E8C",{'from': accounts[0]})
    daaTokenizer.setPositionManager(positionManager,{'from': accounts[0]})
    daaTokenizer.setTokenizedShare(tokenizedShare,{'from': accounts[0]})
    daaTokenizer.setOracleHandler(oracleHandler,{'from': accounts[0]})
    pass

@pytest.fixture(scope="session")
def uniswap_usdc_exchange(interface):
    yield interface.IUniswapV2Exchange('0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff')

@pytest.fixture(scope="module",autouse=True)
def buy_usdc(accounts, usdc, uniswap_usdc_exchange):
    uniswap_usdc_exchange.swapExactETHForTokens(
        1,  # minimum amount of tokens to purchase
        ['0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270','0x2791bca1f2de4661ed88a30c99a7a9449aa84174'],
        accounts[0],
        9999999999,  # timestamp
        {
            'from': accounts[5],
            'value': "99 ether"
        }
    )

@pytest.fixture(scope="module",autouse=True)
def buy_weth(accounts, usdc, uniswap_usdc_exchange):
    uniswap_usdc_exchange.swapExactETHForTokens(
        1,  # minimum amount of tokens to purchase
        ['0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270','0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619'],
        accounts[1],
        9999999999,  # timestamp
        {
            'from': accounts[7],
            'value': "99 ether"
        }
    )

###############

# @pytest.mark.parametrize("gnosisSafe", ["0x933966159085a669279025283A6d250B505f4E8C", "0x213997398DdD5BBd98309428fa3Ae017D5570603"])
def test_init(AaveConnector,accounts, daaTokenizer,gnosisSafe):
    assert daaTokenizer.address == daaTokenizer._whitelisted()
    assert gnosisSafe == daaTokenizer._safe()
    assert daaTokenizer._positionManager() != "0x0000000000000000000000000000000000000000"

def test_proxy(accounts,usdc,positionManager,oracleHandler,tokenizedShare, daaTokenizer,gnosisSafe):
    dev = accounts[0]
    proxy = ProxyHandler.deploy(daaTokenizer.address,{'from': dev})
    proxyModule = Contract.from_abi("DaaTokenizer", proxy.address, DaaTokenizer.abi)
    assert(proxyModule.initialized() == False)
    proxyModule.initialize("0x933966159085a669279025283A6d250B505f4E8C",{'from': dev})
    assert(proxyModule.initialized() == True)
    assert(proxyModule.owner() == dev)
    proxyModule.setPositionManager(positionManager,{'from': dev})
    proxyModule.setTokenizedShare(tokenizedShare,{'from': dev})
    proxyModule.setOracleHandler(oracleHandler,{'from': dev})
    assert proxyModule.calculateNav() == daaTokenizer.calculateNav()
    assert proxyModule.getTotalSharesOutstanding() == daaTokenizer.getTotalSharesOutstanding()
    assert proxyModule.getPricePerShare() == daaTokenizer.getPricePerShare()

def test_mintTokenizedShares(daaTokenizer,tokenizedShare):
    tokenizedShare.mint(accounts[0],10**6,{"from": accounts[0]})
    assert tokenizedShare.totalSupply() == 10**6
    assert daaTokenizer.getTotalSharesOutstanding() == 10**6

@pytest.mark.parametrize("gnosisSafe", ["0x933966159085a669279025283A6d250B505f4E8C", "0x213997398DdD5BBd98309428fa3Ae017D5570603"])
def test_initialPriceLogic(daaTokenizer,usdc,gnosisSafe,tokenizedShare, aaveConnector):
    assert daaTokenizer.getPricePerShare() == 1000000
    assert tokenizedShare.totalSupply() == 0
    amountToDeposit = 10* 10**6
    expectedShares = 10* 10**6
    usdc.approve(daaTokenizer, amountToDeposit,{"from": accounts[0]})
    sharesIssued = daaTokenizer.deposit("USDC",amountToDeposit,{"from": accounts[0]})
    assert sharesIssued.return_value == amountToDeposit
    assert tokenizedShare.totalSupply() == expectedShares 
    assert tokenizedShare.balanceOf(accounts[0]) == expectedShares

def test_transferToSafe(daaTokenizer,gnosisSafe,usdc, positionManager,tokenizedShare):
    amountToDeposit = 10* 10**6
    assert usdc.balanceOf(accounts[0]) > 0
    balancePre = usdc.balanceOf(gnosisSafe)
    usdc.approve(daaTokenizer, 100*10**6,{"from": accounts[0]})
    sharesIssued = daaTokenizer.deposit("USDC",amountToDeposit,{"from": accounts[0]})
    assert usdc.balanceOf(gnosisSafe) == balancePre + amountToDeposit

def test_depositShareIssuance(daaTokenizer,usdc,gnosisSafe,tokenizedShare):
    # deposit 10 dollars
    amountToDeposit = 10* 10**6
    # issue 1 share (6 decimals)
    sharesToIssue = 10**6
    nav = daaTokenizer.calculateNav()
    pricePerShare = daaTokenizer.getPricePerShare()
    usdc.approve(daaTokenizer, 100*10**6,{"from": accounts[0]})
    sharesIssued = daaTokenizer.deposit("USDC",amountToDeposit,{"from": accounts[0]})
    assert sharesIssued.return_value == amountToDeposit / pricePerShare * 10**6
    assert tokenizedShare.balanceOf(accounts[0]) == sharesIssued.return_value

def test_wethDeposit(weth,gnosisSafe, tokenizedShare,oracleHandler,daaTokenizer):
    gnosisSafe.enableModule(daaTokenizer, {'from': gnosisSafe})
    sharesToIssue = 10**6 # issue 1 share (6 decimals)
    amountToDepositUsd = 10* 10**6 # around 10 usd 
    daaTokenizer.addSupportedCurrency("WETH","0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619",False,{'from': accounts[0]})
    weth.approve(daaTokenizer,10**18,{"from": accounts[1]})
    nav = daaTokenizer.calculateNav()
    pricePerShare = daaTokenizer.getPricePerShare()
    ethPrice = oracleHandler.getETHLatestPrice()
    scaledPrice = oracleHandler.scalePrice(ethPrice,8,6)
    amountToDeposit = 10**18 * amountToDepositUsd / scaledPrice # around 10 usd in eth
    expectedShares = amountToDepositUsd / pricePerShare * 10**6
    sharesIssued = daaTokenizer.deposit("WETH", amountToDeposit, {"from": accounts[1]})
    assert sharesIssued.return_value == math.floor(expectedShares) or sharesIssued.return_value == math.floor(expectedShares)-1
    assert tokenizedShare.balanceOf(accounts[1]) == sharesIssued.return_value    

def test_externalPositionNav(daaTokenizer,usdc,gnosisSafe,tokenizedShare, aaveConnector):
    # deposit 10 dollars
    amountToDeposit = 10* 10**6
    # issue 1 share (6 decimals)
    sharesToIssue = 10**6
    # add ext position to aave for safe
    # random address that has usdc
    addressWithUsdc = "0xf9211FfBD6f741771393205c1c3F6D7d28B90F03"
    # give safe some usdc
    usdc.transfer(aaveConnector, 100*10**6, {'from': addressWithUsdc})
    aaveConnector.deposit(usdc, 100*10**6, {"from": gnosisSafe})
    # this should be the internal nav 
    nav = daaTokenizer.calculateNav()  # +100*10**6
    pricePerShare = daaTokenizer.getPricePerShare()
    usdc.approve(daaTokenizer, 100*10**6,{"from": accounts[0]})
    sharesIssued = daaTokenizer.deposit("USDC",amountToDeposit,{"from": accounts[0]})
    assert sharesIssued.return_value == amountToDeposit / pricePerShare * 10**6
    assert tokenizedShare.balanceOf(accounts[0]) == sharesIssued.return_value

def test_externalPositionNavWithDebt(daaTokenizer,usdc,gnosisSafe,tokenizedShare, aaveConnector):
    # deposit 10 dollars
    amountToDeposit = 10* 10**6
    # amount to borrow
    amountToBorrow = 3* 10**6
    variableDebtTokenAddress = "0x248960A9d75EdFa3de94F7193eae3161Eb349a12"
    # issue 1 share (6 decimals)
    sharesToIssue = 10**6
    # add ext position to aave for safe
    # random address that has usdc
    addressWithUsdc = "0xf9211FfBD6f741771393205c1c3F6D7d28B90F03"
    # give safe some usdc
    usdc.transfer(aaveConnector, 100*10**6, {'from': addressWithUsdc})
    aaveConnector.deposit(usdc, 100*10**6, {"from": gnosisSafe})
    # the contract is borrowing on behalf of sender, hence allowance
    balancePreBorrow = usdc.balanceOf(gnosisSafe)
    interface.IVariableDebtToken(variableDebtTokenAddress).approveDelegation(aaveConnector, 100*10**6,{"from": gnosisSafe})
    aaveConnector.borrow(usdc, 3*10**6, 2,{"from": gnosisSafe})
    assert usdc.balanceOf(gnosisSafe) - 3*10**6  == balancePreBorrow
    # this should be the internal nav 
    nav = daaTokenizer.calculateNav() # + 100*10**6 - 3*10**6
    pricePerShare = daaTokenizer.getPricePerShare()
    usdc.approve(daaTokenizer, 100*10**6,{"from": accounts[0]})
    sharesIssued = daaTokenizer.deposit("USDC",amountToDeposit,{"from": accounts[0]})
    assert sharesIssued.return_value == amountToDeposit / pricePerShare * 10**6
    assert tokenizedShare.balanceOf(accounts[0]) == sharesIssued.return_value

# revert: not enough funds in tokenizer
@pytest.mark.xfail
def test_redeemFail(daaTokenizer,usdc,gnosisSafe,tokenizedShare, aaveConnector):
    gnosisSafe.enableModule(daaTokenizer, {'from': gnosisSafe})
    # issue 1 share (6 decimals)
    sharesToIssue = 10**6
    # deposit 10 dollars
    amountToDeposit = 10* 10**6
    preWithdrawalBalance = usdc.balanceOf(accounts[0])
    safeInitBalance = usdc.balanceOf(gnosisSafe)
    usdc.approve(daaTokenizer, 100*10**6,{"from": accounts[0]})
    # add ext position to aave for safe
    # random address that has usdc
    addressWithUsdc = "0xf9211FfBD6f741771393205c1c3F6D7d28B90F03"
    # give safe some usdc
    usdc.transfer(aaveConnector, 100*10**6, {'from': addressWithUsdc})
    sharesIssued = daaTokenizer.deposit("USDC",amountToDeposit,{"from": accounts[0]})
    # redeem
    daaTokenizer.redeem(tokenizedShare.balanceOf(accounts[0]),{"from": accounts[0]})

def test_navTransfer(daaTokenizer,usdc,gnosisSafe,tokenizedShare, aaveConnector):
    gnosisSafe.enableModule(daaTokenizer, {'from': gnosisSafe})
    # issue 1 share (6 decimals)
    sharesToIssue = 10**6
    # deposit 10 dollars
    amountToDeposit = 10* 10**6
    preWithdrawalBalance = usdc.balanceOf(accounts[0])
    usdc.approve(daaTokenizer, 100*10**6,{"from": accounts[0]})
    sharesIssued = daaTokenizer.deposit("USDC",amountToDeposit,{"from": accounts[0]})
    # manual transfer from safe to conctract
    pricePerSharePre = daaTokenizer.getPricePerShare()
    usdc.transfer(daaTokenizer,daaTokenizer.calcBaseAmount(tokenizedShare.balanceOf(accounts[0])),{'from': gnosisSafe})
    assert pricePerSharePre == daaTokenizer.getPricePerShare()
    

def test_redeem(daaTokenizer,usdc,gnosisSafe,tokenizedShare, aaveConnector):
    gnosisSafe.enableModule(daaTokenizer, {'from': gnosisSafe})
    # deposit 10 dollars
    amountToDeposit = 10* 10**6
    preWithdrawalBalance = usdc.balanceOf(accounts[0])
    usdc.approve(daaTokenizer, 100*10**6,{"from": accounts[0]})
    sharesIssued = daaTokenizer.deposit("USDC",amountToDeposit,{"from": accounts[0]})
    # manual transfer from safe to conctract
    usdc.transfer(daaTokenizer,daaTokenizer.calcBaseAmount(tokenizedShare.balanceOf(accounts[0])),{'from': gnosisSafe})
    # redeem
    daaTokenizer.redeem(tokenizedShare.balanceOf(accounts[0]),{"from": accounts[0]})
    postWithdrawalBalance = usdc.balanceOf(accounts[0])
    assert preWithdrawalBalance >= postWithdrawalBalance -10 and  preWithdrawalBalance <= postWithdrawalBalance +10 # rounding issue of 0.00000X dollars
    assert tokenizedShare.balanceOf(accounts[0]) == 0

def test_redeemPartial(daaTokenizer,usdc,gnosisSafe,tokenizedShare, aaveConnector):
    gnosisSafe.enableModule(daaTokenizer, {'from': gnosisSafe})
    # issue 1 share (6 decimals)
    sharesToIssue = 10**6
    # deposit 10 dollars
    amountToDeposit = 10* 10**6
    preWithdrawalBalance = usdc.balanceOf(accounts[0])
    safeInitBalance = usdc.balanceOf(gnosisSafe)
    usdc.approve(daaTokenizer, 100*10**6,{"from": accounts[0]})
    # random address that has usdc
    addressWithUsdc = "0xf9211FfBD6f741771393205c1c3F6D7d28B90F03"
    # give safe some usdc
    usdc.transfer(aaveConnector, 100*10**6, {'from': addressWithUsdc})
    # deposit
    usdc.approve(daaTokenizer, 100*10**6,{"from": accounts[0]})
    sharesIssued = daaTokenizer.deposit("USDC",amountToDeposit,{"from": accounts[0]})
    # manual transfer from safe to conctract
    usdc.transfer(daaTokenizer,daaTokenizer.calcBaseAmount(tokenizedShare.balanceOf(accounts[0])),{'from': gnosisSafe})
    # redeem
    daaTokenizer.redeem(sharesIssued.return_value/2,{"from": accounts[0]})
    postWithdrawalBalance = usdc.balanceOf(accounts[0])
    assert preWithdrawalBalance >= postWithdrawalBalance + (amountToDeposit/2) -10 and preWithdrawalBalance <= postWithdrawalBalance + (amountToDeposit/2) +10 # rounding issue of 0.00000X dollars
    assert tokenizedShare.balanceOf(accounts[0]) == (sharesIssued.return_value+1)/2 

def test_redeemPartialAndDeposit(daaTokenizer,usdc,gnosisSafe,tokenizedShare, aaveConnector):
    gnosisSafe.enableModule(daaTokenizer, {'from': gnosisSafe})
    # issue 1 share (6 decimals)
    sharesToIssue = 10**6
    # deposit 10 dollars
    amountToDeposit = 10* 10**6
    preWithdrawalBalance = usdc.balanceOf(accounts[0])
    safeInitBalance = usdc.balanceOf(gnosisSafe)
    usdc.approve(daaTokenizer, 100*10**6,{"from": accounts[0]})
    # random address that has usdc
    addressWithUsdc = "0xf9211FfBD6f741771393205c1c3F6D7d28B90F03"
    # give safe some usdc
    usdc.transfer(aaveConnector, 100*10**6, {'from': addressWithUsdc})
    # deposit
    usdc.approve(daaTokenizer, 100*10**6,{"from": accounts[0]})
    sharesIssued = daaTokenizer.deposit("USDC",amountToDeposit,{"from": accounts[0]})
    # manual transfer from safe to conctract
    usdc.transfer(daaTokenizer,daaTokenizer.calcBaseAmount(tokenizedShare.balanceOf(accounts[0])),{'from': gnosisSafe})
    # redeem
    daaTokenizer.redeem(sharesIssued.return_value/2,{"from": accounts[0]})
    postWithdrawalBalance = usdc.balanceOf(accounts[0])
    assert preWithdrawalBalance >= postWithdrawalBalance + (amountToDeposit/2) -10 and preWithdrawalBalance <= postWithdrawalBalance + (amountToDeposit/2) +10 # rounding issue of 0.00000X dollars
    assert tokenizedShare.balanceOf(accounts[0]) == (sharesIssued.return_value+1)/2 


    
