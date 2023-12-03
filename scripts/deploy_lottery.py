from brownie import Lottery, config, network
from scripts.helpful import (
    var_account,
    get_contract,
    vrfSub,
    LOCAL_BLOCKCHAIN_ENVIRONMENT,
)
from datetime import datetime, timedelta
import time


def deploy_lottery():
    account = var_account()
    lottery = Lottery.deploy(
        config["networks"][network.show_active()]["subId"],
        config["networks"][network.show_active()]["keyHash"],
        get_contract("eth_usd_priceFeed").address,
        get_contract("vrfCoordinator").address,
        {"from": account},
        publish_source=config["networks"][network.show_active()].get("verify", False),
    )  # deploying LOTTERY
    time.sleep(1)
    print("Deployed lottery!")
    print("VRFCoordinator address: ", get_contract("vrfCoordinator").address)
    print("Lottery deployed at: ", lottery.address)
    return lottery


lotteryOperator = var_account()
operatorCommissonPercentage = 10
expiration = int((datetime.now() + timedelta(minutes=90)).timestamp())
# Expiration:  1701459385


def startLottery(maxTicket, ticketPrice):
    account = var_account()
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
    account = var_account()
    # account1 = get_account()
    lottery = Lottery[-1]  # Accessing the deployed Lottery contract
    tx = lottery.buyTickets(
        _lotteryId,
        tickets,
        {
            "from": account,
            "value": payment,
        },
    )
    tx.wait(1)
    time.sleep(1)

    print(f"{tickets} tickets bought successfully for lottery ({_lotteryId})")
    remTickets = lottery.getRemainingTickets(_lotteryId)
    print("Ticket Remaining: ", remTickets)


def endLottery(lotteryId):
    account = var_account()
    lottery = Lottery[-1]
    # fundLink = 100000000000000000000000
    vrfSub()  # for VRFMock subscription
    tx = lottery.endLottery(lotteryId, {"from": account})
    requestId = tx.events["requestLotteryWinnerSent"]["requestId"]
    print("Request_Id: ", requestId)
    tx.wait(1)
    time.sleep(60)
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENT:
        get_contract("vrfCoordinator").fulfillRandomWords(
            requestId, lottery.address, {"from": account}
        )


def drawLotteryWinner(lotteryId):
    account = var_account()
    lottery = Lottery[-1]
    lotteryWinner = lottery.drawLotteryWinner(lotteryId, {"from": account})
    lotteryWinner.wait(1)
    time.sleep(1)
    event_winner = lotteryWinner.events["LotteryWinner"]["lotteryWinner"]
    print(f"The winner of the lottery is {event_winner}")


def claimLottery(lotteryId):
    account = var_account()
    lottery = Lottery[-1]
    tx = lottery.claimLottery(lotteryId, {"from": account})
    tx.wait(1)
    time.sleep(1)
    amount = tx.events["lotteryClaimed"]["amount"]
    lotteryWinner = tx.events["lotteryClaimed"]["lotteryWinner"]
    print(f"Congratulation: {lotteryWinner} has claimed {amount}")


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
    drawLotteryWinner(lotteryId)
    claimLottery(lotteryId)
