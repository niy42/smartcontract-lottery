from brownie import VRFCoordinatorV2Mock, network, accounts, Lottery, config
from scripts.helpful import LOCAL_BLOCKCHAIN_ENVIRONMENT, get_account

basefee = 2500000000000000000
gasPriceLink = 100000000000000000


def userVRFMock():
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENT:
        account = get_account(id="my_account")
        account1 = get_account()
        if len(VRFCoordinatorV2Mock) <= 0:
            VRFCoordinatorV2Mock.deploy(basefee, gasPriceLink, {"from": account1})
        VRF_contract = VRFCoordinatorV2Mock[-1]
        VRF = VRF_contract.createSubscription({"from": account1})
        subId = VRF.events["SubscriptionCreated"]["subId"]
        print(f"The subscription ID is: {subId}")

        # fund subscription
        VRF_contract.fundSubscription(
            subId, 3000000000000000000000000000, {"from": account1}
        )

        # add consumer
        lottery = Lottery[-1]
        VRF_contract.addConsumer(subId, lottery.address, {"from": account1})

        # VRF randomness request
        keyHash = config["networks"][network.show_active()]["keyHash"]
        minimumRequestConfirmations = 1
        callbackGasLimit = 1
        numWords = 2
        tx = VRF_contract.requestRandomWords(
            keyHash,
            subId,
            minimumRequestConfirmations,
            callbackGasLimit,
            numWords,
            {"from": account1},
        )
        tx.wait(1)
        requestId = tx.events["RandomWordsRequested"]["requestId"]
        print("requestID: ", requestId)


def fulfill():
    # VRF fulfill Randomness
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENT:
        account = get_account(id="my_account")
        account1 = get_account()
        if len(VRFCoordinatorV2Mock) <= 0:
            VRFCoordinatorV2Mock.deploy(basefee, gasPriceLink, {"from": account1})
        VRF_contract = VRFCoordinatorV2Mock[-1]
        lottery = Lottery[-1]
        fulfil = VRF_contract.fulfillRandomWords(1, lottery.address, {"from": account1})
        fulfil.wait(1)
        success = fulfil.events["RandomWordFulfilled"]["success"]
        print("Success is ", success)


def main():
    userVRFMock()
