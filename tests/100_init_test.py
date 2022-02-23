from brownie import accounts, Contract, DaaModule, chain
from brownie.test import given, strategy
import pytest


# @given(amount=strategy('uint256', max_value=10**18))

###############
@pytest.fixture(autouse=True)
def doSomething( accounts):
    pass

# get usdc
@pytest.fixture(scope="session")
def usdc(interface):
    yield interface.IERC20Minimal('0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48')

# get 1inch
@pytest.fixture(scope="session")
def oneinchToken(interface):
    yield interface.IERC20Minimal('0x111111111117dc0aa78b770fa6a738034120c302')


# get random safe
@pytest.fixture(scope="session")
def gnosisSafe(interface):
    yield interface.IGnosisSafe('0x5E89f8d81C74E311458277EA1Be3d3247c7cd7D1')


@pytest.fixture(autouse=True)
def def_setters( accounts):
    # set contracts
    pass

###############


def test_init(accounts, daaModule,gnosisSafe):
    assert accounts[0] == daaModule._whitelisted()
    assert gnosisSafe == daaModule._safe()

def test_spendERC20(accounts,oneinchToken, daaModule,gnosisSafe):
    gnosisSafe.enableModule(daaModule, {'from': gnosisSafe})
    whitelisted = daaModule._whitelisted()
    spenders = gnosisSafe.getOwners()
    balancePre = oneinchToken.balanceOf(whitelisted)
    daaModule.executeTransfer(oneinchToken,10*10**6,{'from': spenders[0]})
    assert balancePre == oneinchToken.balanceOf(whitelisted) - 10*10**6
    
def test_spendETH(accounts,oneinchToken, daaModule,gnosisSafe):
    gnosisSafe.enableModule(daaModule, {'from': gnosisSafe})
    whitelisted = accounts.at(daaModule._whitelisted())
    spenders = gnosisSafe.getOwners()
    # give safe some eth
    accounts[1].transfer(gnosisSafe, '5 ether')
    balancePre = whitelisted.balance()
    daaModule.executeTransfer("0x0000000000000000000000000000000000000000",'1 ether',{'from': spenders[0]})
    assert whitelisted.balance() == (balancePre + "1 ether") 
    
# revert: sender not safe owner
@pytest.mark.xfail
def test_spendFailNonOwner(accounts,oneinchToken, daaModule,gnosisSafe):
    gnosisSafe.enableModule(daaModule, {'from': gnosisSafe})
    whitelisted = accounts.at(daaModule._whitelisted())
    spenders = gnosisSafe.getOwners()
    # give safe some eth
    accounts[1].transfer(gnosisSafe, '5 ether')
    balancePre = whitelisted.balance()
    daaModule.executeTransfer("0x0000000000000000000000000000000000000000",'1 ether',{'from': accounts[0]})
    pass


