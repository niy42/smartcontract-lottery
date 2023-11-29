from brownie import Lottery, config, network, VRFCoordinatorV2Mock
from scripts.helpful import get_account, get_contract, keyHash, basefee, gasPriceLink
from scripts.subscription import subscriptionId
from datetime import datetime, timedelta
from scripts.chainlink_sub import VRFCoordinatorMockV2
import time

# from web3 import Web3


# deploy_lot is only for testing
def deploy_lot():
    account = get_account()
    _keyHash = keyHash()
    lottery = Lottery.deploy(
        1,
        get_contract("eth_usd_priceFeed").address,
        get_contract("vrfCoordinator").address,
        _keyHash,
        {"from": account},
        publish_source=config["networks"][network.show_active()].get("verify", False),
    )
    fund_link = Web3.toWei("30", "ether")
    return lottery


def deploy_lottery():
    account = get_account()
    _keyHash = keyHash()
    _subId = subscriptionId()
    lottery = Lottery.deploy(
        _subId,
        get_contract("eth_usd_priceFeed").address,
        get_contract("vrfCoordinator").address,
        _keyHash,
        {"from": account},
        publish_source=config["networks"][network.show_active()].get("verify", False),
    )  # deploying LOTTERY
    time.sleep(1)
    print("Deployed lottery!")
    print("VRFCoordinator address: ", get_contract("vrfCoordinator").address)
    print("Lottery deployed at: ", lottery.address)


lotteryOperator = get_account()
operatorCommissonPercentage = 10
expiration = int((datetime.now() + timedelta(minutes=5)).timestamp())


def startLottery(maxTicket, ticketPrice):
    account = get_account()
    lottery = Lottery[-1]
    tx = lottery.startLottery(
        lotteryOperator,
        operatorCommissonPercentage,
        maxTicket,
        ticketPrice,
        expiration,
        {"from": account},
    )
    tx.wait(1)
    time.sleep(1)

    # Emitting events
    _event0 = tx.events["lotteryCreated"]["lotteryOperator"]
    _event1 = tx.events["lotteryCreated"]["operatorCommissionPercentage"]
    _event2 = tx.events["lotteryCreated"]["maxTickets"]
    _event3 = tx.events["lotteryCreated"]["ticketPrice"]
    _event4 = tx.events["lotteryCreated"]["expiration"]

    # print to console
    print("Lottery Started!...")
    print("Lottery Operator:", _event0)
    print(f"Lottery operatorCommissionPercentage:   {_event1}")
    print("Maximum Tickets: ", _event2)
    print("Ticket Price: ", _event3)
    print(f"Expiration:  {_event4}")


def getRemainingTickets(_lotteryId):
    lottery = Lottery[-1]
    remTickets = lottery.getRemainingTickets(_lotteryId)
    print("Tickets Remaining: ", remTickets)


def buy_tickets(_lotteryId, tickets, payment):
    account = get_account()
    lottery = Lottery[-1]  # Accessing the deployed Lottery contract
    lottery.BuyTickets(_lotteryId, tickets, {"from": account, "value": payment})
    time.sleep(1)

    print(f"{tickets} tickets bought successfully for lottery ({_lotteryId})")
    remTickets = lottery.getRemainingTickets(_lotteryId)
    print("Ticket Remaining: ", remTickets)


def endLottery(lotteryId):
    subId = subscriptionId()
    account = get_account()
    lottery = Lottery[-1]
    mockVRF = VRFCoordinatorV2Mock[-1]
    mockVRF.createSubscription({"from": account})
    mockVRF.fundSubscription(subId, 2000000000000000000000, {"from": account})
    mockVRF.addConsumer(subId, lottery.address, {"from": account})
    tx = lottery.endLottery(lotteryId, {"from": account})

    time.sleep(60)


def main():
    maxTicket = int(input("Set ticket max: "))
    ticketPrice = int(input("Set ticket price: "))
    deploy_lottery()
    startLottery(maxTicket, ticketPrice)
    lotteryId = int(input("LotteryId: "))  # Get user input for lotteryId
    getRemainingTickets(lotteryId)
    num_tickets = int(
        input("Number of tickets to buy: ")
    )  # Get user input for number of tickets
    payment = int(
        input("Deposit payment per ticket: ")
    )  # Get user input for payment per ticket
    buy_tickets(
        lotteryId, num_tickets, payment
    )  # Pass payment per ticket to buy_tickets()
    endLottery(lotteryId)
