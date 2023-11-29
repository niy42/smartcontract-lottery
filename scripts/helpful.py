from brownie import (
    accounts,
    network,
    config,
    MockV3Aggregator,
    VRFCoordinatorV2Mock,
    Contract,
)
import os

LOCAL_BLOCKCHAIN_ENVIRONMENT = ["ganache-local", "development"]
FORKED_BLOCKCHAIN_ENVIRONMENT = ["mainnet-fork", "mainnet-foke"]


def get_account(index=None, id=None):
    if index:
        return accounts[index]
    if id:
        return accounts.load(id)
    if (
        network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENT
        or network.show_active() in FORKED_BLOCKCHAIN_ENVIRONMENT
    ):
        return accounts[0]
    return accounts.add(config["wallets"]["from_key"])


contract_to_mock = {
    "eth_usd_priceFeed": MockV3Aggregator,
    "vrfCoordinator": VRFCoordinatorV2Mock,
}

DECIMALS = 8
INITIAL_VALUE = 200000000000
basefee = 2500000000000000000
gasPriceLink = 1000000000


def deploy_mocks(decimals=DECIMALS, initial_value=INITIAL_VALUE):
    account = get_account(index=None, id=None)
    if len(MockV3Aggregator) <= 0:
        MockV3Aggregator.deploy(decimals, initial_value, {"from": account})
        VRFCoordinatorV2Mock.deploy(basefee, gasPriceLink, {"from": account})
    print("Deployed!")


def get_contract(contract_name):
    """This contract will grab the contract adrresses from t he brownie config
    if defined, otherwise, it will deploy a mock version of that contract,
    and return that mock contract

        Args:
            contract name (string)
        brownie.network.contract.ProjectContract: The most recently deployed
        version of this contract.
    """
    contract_type = contract_to_mock[contract_name]
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENT:
        if len(contract_type) <= 0:
            # MockV3Aggregator.length
            deploy_mocks()
        contract = contract_type[-1]
    else:
        contract_address = config["networks"][network.show_active][contract_name]
        contract = Contract.from_abi(
            contract_type._name, contract_address, contract_type.abi
        )
    return contract


def keyHash():
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENT:
        return accounts[0]
    return os.getenv("KEYHASH")
