from brownie import (
    accounts,
    network,
    config,
    MockV3Aggregator,
    VRFCoordinatorV2Mock,
    Contract,
)

LOCAL_BLOCKCHAIN_ENVIRONMENT = ["ganache-local", "development"]
FORKED_ENVIRONMENT = ["mainnet-fork", "mainnet-foke"]


def get_account(index=None, id=None):
    if index:
        return accounts[index]
    if id:
        return accounts.load(id)
    if (
        network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENT
        or network.show_active() in FORKED_ENVIRONMENT
    ):
        return accounts[0]
    return accounts.add(config["wallets"]["from_key"])


DECIMALS = 8
INITIAL_VALUE = 200000000000
BASE_FEE = 2500000000000000000
GAS_PRICE_LINK = 1000000000


def deploy_mocks(
    decimals=DECIMALS,
    initial_value=INITIAL_VALUE,
    baseFee=BASE_FEE,
    gasPriceLink=GAS_PRICE_LINK,
):
    MockV3Aggregator.deploy(decimals, initial_value, {"from": get_account()})
    VRFCoordinatorV2Mock.deploy(baseFee, gasPriceLink, {"from": get_account()})
    MockV3Aggregator[-1]
    VRFCoordinatorV2Mock[-1]


contract_to_mock = {
    "eth_usd_priceFeed": MockV3Aggregator,
    "vrfCoordintor": VRFCoordinatorV2Mock,
}


def get_contract(contract_name):
    """This contract fetches addresses from brownie config
    for mainnet and persistent development networks (external),
    but deploys a dummy(mock) if testing in a local context.

    Args:
        contract_name(string)
    brownie.network.contract.ProjectContract
    """
    contract_type = contract_to_mock[contract_name]
    if network.show_active in LOCAL_BLOCKCHAIN_ENVIRONMENT:
        if len(contract_type) <= 0:
            deploy_mocks()
            return contract_type[-1]
        contract_address = config["networks"][network.show_active()]["contract_name"]
        return Contract.from_abi(
            contract_type._name, contract_address, contract_type.abi
        )


def keyHash_test():
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENT:
        return config["networks"][network.show_active()]["keyHash"]
    return accounts.add(config["wallets"]["from_key"])
