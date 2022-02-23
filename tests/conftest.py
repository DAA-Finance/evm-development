#!/usr/bin/python3

import pytest


@pytest.fixture(scope="function", autouse=True)
def isolate(fn_isolation):
    # perform a chain rewind after completing each test, to ensure proper isolation
    # https://eth-brownie.readthedocs.io/en/v1.10.3/tests-pytest-intro.html#isolation-fixtures
    pass

@pytest.fixture(scope="module")
def daaModule(DaaModule, accounts):
    return DaaModule.deploy(accounts[0], "0x5E89f8d81C74E311458277EA1Be3d3247c7cd7D1", {'from': accounts[0]})


# @pytest.fixture(scope="module")
# def baseLibrary(BaseLibrary,accounts):
#     return BaseLibrary.deploy({'from': accounts[0]})
