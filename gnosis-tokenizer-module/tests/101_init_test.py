from brownie import accounts, Contract, DaaTokenizer, chain
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

@pytest.mark.skip(reason="Testing on polygon")
def test_init(accounts, daaTokenizer,gnosisSafe):
    assert accounts[0] == daaTokenizer._whitelisted()
    assert gnosisSafe == daaTokenizer._safe()

@pytest.mark.skip(reason="Testing on polygon")
def test_spendERC20(accounts,oneinchToken, daaTokenizer,gnosisSafe):
    gnosisSafe.enableModule(daaTokenizer, {'from': gnosisSafe})
    whitelisted = daaTokenizer._whitelisted()
    spenders = gnosisSafe.getOwners()
    balancePre = oneinchToken.balanceOf(whitelisted)
    daaTokenizer.executeTransfer(oneinchToken,10*10**6,{'from': spenders[0]})
    assert balancePre == oneinchToken.balanceOf(whitelisted) - 10*10**6
    
@pytest.mark.skip(reason="Testing on polygon")
def test_spendETH(accounts,oneinchToken, daaTokenizer,gnosisSafe):
    gnosisSafe.enableModule(daaTokenizer, {'from': gnosisSafe})
    whitelisted = accounts.at(daaTokenizer._whitelisted())
    spenders = gnosisSafe.getOwners()
    # give safe some eth
    accounts[1].transfer(gnosisSafe, '5 ether')
    balancePre = whitelisted.balance()
    daaTokenizer.executeTransfer("0x0000000000000000000000000000000000000000",'1 ether',{'from': spenders[0]})
    assert whitelisted.balance() == (balancePre + "1 ether") 
    
# # revert: sender not safe owner
# @pytest.mark.xfail
@pytest.mark.skip(reason="Testing on polygon")
def test_spendFailNonOwner(accounts,oneinchToken, daaTokenizer,gnosisSafe):
    gnosisSafe.enableModule(daaTokenizer, {'from': gnosisSafe})
    whitelisted = accounts.at(daaTokenizer._whitelisted())
    spenders = gnosisSafe.getOwners()
    # give safe some eth
    accounts[1].transfer(gnosisSafe, '5 ether')
    balancePre = whitelisted.balance()
    daaTokenizer.executeTransfer("0x0000000000000000000000000000000000000000",'1 ether',{'from': accounts[0]})
    pass


