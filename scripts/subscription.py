from brownie import network
from scripts.helpful import LOCAL_BLOCKCHAIN_ENVIRONMENT


def subscriptionId():
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENT:
        subId = 7056
    else:
        subId = 1
    return subId
