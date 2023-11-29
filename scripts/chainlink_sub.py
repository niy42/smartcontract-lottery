from brownie import VRFCoordinatorV2Mock, MockV3Aggregator, Lottery
from scripts.helpful import DECIMALS, INITIAL_VALUE, basefee, get_account, gasPriceLink
from scripts.subscription import subscriptionId
import time


def VRFCoordinatorMockV2():
    # Create subscription
    account = get_account()
    if len(VRFCoordinatorV2Mock) <= 0:
        VRFCoordinatorV2Mock.deploy(basefee, gasPriceLink, {"from": account})
    mockVRF_contract = VRFCoordinatorV2Mock[-1]
    print("VRFCoordinator Address: ", mockVRF_contract.address)
    createSub = mockVRF_contract.createSubscription({"from": account})
    createSub.wait(1)
    time.sleep(1)
    subId = subscriptionId()
    print(f"My subcription_Id is: {subId}")

    # funding subscription
    fund_link = 2000000000000000000000000
    fundSub = mockVRF_contract.fundSubscription(subId, fund_link, {"from": account})
    fundSub.wait(1)
    time.sleep(1)
    tx = fundSub.events["SubscriptionFunded"]["newBalance"]
    print(tx, "added to your account")

    fund_link = 1000000000000000000000000
    fundSub = mockVRF_contract.fundSubscription(subId, fund_link, {"from": account})
    fundSub.wait(1)
    time.sleep(1)
    tx = fundSub.events["SubscriptionFunded"]["newBalance"]
    print(fund_link, "added to your account")
    print("New vault balance is: ", tx)

    fund_link = 2000000000000000000000000
    fundSub = mockVRF_contract.fundSubscription(subId, fund_link, {"from": account})
    fundSub.wait(1)
    time.sleep(1)
    tx_Amount = fundSub.events["SubscriptionFunded"]["newBalance"]
    print("Total vault amount is: ", tx_Amount)

    # addConsumer
    lottery = Lottery[-1]
    tx_Addconsumer = mockVRF_contract.addConsumer(
        subId, lottery.address, {"from": account}
    )
    tx_Addconsumer.wait(1)
    time.sleep(1)
    consumerAddress = tx_Addconsumer.events["ConsumerAdded"]["consumer"]
    print("This is the consumer Address: ", consumerAddress)

    # consumerAdded
    consumerAdded = mockVRF_contract.consumerIsAdded(subId, consumerAddress)
    if consumerAdded:
        print("..........Consumer is Added")


def fulfillRandomWords():
    requestFulfiled = mockVRF_contract.fulfillRandomWords(
        subId, lottery.address, {"from": account}
    )
    requestFulfiled.wait(1)
    time.sleep(1)
    tx_success = requestFulfiled.events["RequestFulfilled"]["success"]
    print("Success is: ", tx_success)
