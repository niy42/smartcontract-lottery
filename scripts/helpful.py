from brownie import (
    accounts,
    network,
    config,
    MockV3Aggregator,
    VRFCoordinatorV2Mock,
    Contract,
    Lottery,
    VRFv2SubscriptionManager,
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


DECIMALS = 8
INITIAL_VALUE = 200000000000
basefee = 2500000000000000000
gasPriceLink = 1000000000000000000


def deploy_mocks(decimals=DECIMALS, initial_value=INITIAL_VALUE):
    account = get_account()
    MockV3Aggregator.deploy(decimals, initial_value, {"from": account})
    mockVRF_contract = VRFCoordinatorV2Mock.deploy(
        basefee, gasPriceLink, {"from": account}
    )
    contract = mockVRF_contract
    print("Deployed!")
    return contract


def deploy_VRFSub_manager():
    account = var_account()
    if len(VRFCoordinatorV2Mock) <= 0:
        VRFv2SubscriptionManager.deploy({"from": account})
    vrf_manager = VRFv2SubscriptionManager[-1]
    return vrf_manager


contract_to_mock = {
    "eth_usd_priceFeed": MockV3Aggregator,
    "vrfCoordinator": VRFCoordinatorV2Mock,
}


def get_contract(contract_name):
    """This contract will grab the contract adrresses from the brownie config
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
            # VRFCoordinatorV2Mock.length
            deploy_mocks()
        contract = contract_type[-1]
    else:
        contract_address = config["networks"][network.show_active()][contract_name]
        contract = Contract.from_abi(
            contract_type._name, contract_address, contract_type.abi
        )
    return contract


def vrfSub():
    # vrf_manager = deploy_VRFSub_manager()
    lottery = Lottery[-1]
    account = var_account()
    fundLink = 100000000000000000000000
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENT:
        get_contract("vrfCoordinator").createSubscription({"from": account})
        get_contract("vrfCoordinator").addConsumer(
            config["networks"][network.show_active()]["subId"],
            lottery.address,
            {"from": account},
        )
        get_contract("vrfCoordinator").fundSubscription(
            config["networks"][network.show_active()]["subId"],
            fundLink,
            {"from": account},
        )
    # vrf_manager.addConsumer(lottery.address, {"from": account})
    # print(f"My subId is: {vrf_manager.subscriptionId()}")


def var_account():
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENT:
        return get_account()
    return get_account(id="my_account")
