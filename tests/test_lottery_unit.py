from brownie import network, exceptions, config
from scripts.deploy_lottery import deploy_lottery
from scripts.helpful import LOCAL_BLOCKCHAIN_ENVIRONMENT, get_account, get_contract
import pytest, time


def test_cant_call_startLottery_only_owner():
    # Arrange
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENT:
        pytest.skip()

    # Act / Assert
    lottery = deploy_lottery()  # deployed by get_account() --> operator/owner
    # Test passed, only operator/owner can call function startLottery
    with pytest.raises(exceptions.VirtualMachineError):
        lottery.startLottery(
            get_account(),  # operator/owner
            10,
            10,
            100,
            500000000000000000000,
            {
                "from": get_account(id="my_account")
            },  # "get_account(id="my_account")" wasnt the address that deployed the contract.
            # Thus, caller not operator
        )
    # test_buy_tickets.py


def test_buy_tickets():
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENT:
        pytest.skip()
    account = get_account()
    lottery = deploy_lottery()
    # Set up variables for testing
    lotteryId = 0
    lotteryOperator = account
    operatorCommissonPercentage = 10
    ticketPrice = 100  # Replace with your actual ticket price
    expiration = 500000000000000  # Replace with expiration timestamp
    maxTicket = 50  # Replace with available tickets for the lottery

    # Initialize lottery parameters
    lottery.startLottery(
        lotteryOperator,
        operatorCommissonPercentage,
        maxTicket,
        ticketPrice,
        expiration,
        {"from": account},
    )

    # Simulate ticket purchase
    tickets_to_buy = 3
    amount = tickets_to_buy * ticketPrice
    lottery.buyTickets(lotteryId, tickets_to_buy, {"from": account, "value": amount})

    # Assertions to verify the purchase
    assert amount >= ticketPrice  # Check amount greater or equal to price
    assert (
        lottery.getRemainingTickets(lotteryId)
    ) != tickets_to_buy  # Check purchased tickets
    # Add more assertions based on your contract logic


def test_can_end_Lottery():
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENT:
        pytest.skip()
    account = get_account()
    lottery = deploy_lottery()
    lotteryId = int(input("Enter lotteryId: "))
    lottery.startLottery(account, 10, 10, 100, 500000000000000000, {"from": account})
    get_contract("vrfCoordinator").createSubscription({"from": account})
    get_contract("vrfCoordinator").addConsumer(
        config["networks"][network.show_active()]["subId"],
        lottery.address,
        {"from": account},
    )
    fundLink = 100000000000000000000000
    get_contract("vrfCoordinator").fundSubscription(
        config["networks"][network.show_active()]["subId"], fundLink, {"from": account}
    )
    tx = lottery.endLottery(lotteryId, {"from": account})
    tx.wait(1)
    time.sleep(2)


def test_can_pick_winner():
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENT:
        pytest.skip()
    lotteryId = 0
    lottery = deploy_lottery()
    account = get_account()
    lottery.startLottery(
        get_account(id="my_account"), 10, 10, 100, 5000000000000000, {"from": account}
    )
    lottery.buyTickets(lotteryId, 2, {"from": get_account(index=0), "value": 200})
    lottery.buyTickets(lotteryId, 3, {"from": get_account(index=1), "value": 300})
    lottery.buyTickets(lotteryId, 1, {"from": get_account(index=2), "value": 100})
    get_contract("vrfCoordinator").createSubscription({"from": account})
    get_contract("vrfCoordinator").addConsumer(
        config["networks"][network.show_active()]["subId"],
        lottery.address,
        {"from": account},
    )
    fundLink = 500000000000000000000000
    get_contract("vrfCoordinator").fundSubscription(
        config["networks"][network.show_active()]["subId"], fundLink, {"from": account}
    )
    tx = lottery.endLottery(lotteryId, {"from": account})
    requestId = tx.events["requestLotteryWinnerSent"]["requestId"]
    tx.wait(1)
    time.sleep(6)
    my_array = [28, 92]
    get_contract("vrfCoordinator").fulfillRandomWordsWithOverride(
        requestId, lottery.address, my_array, {"from": account}
    )
    tx = lottery.drawLotteryWinner(lotteryId, {"from": account})
    lotteryWinner = tx.events["LotteryWinner"]["lotteryWinner"]
    print(f"Winner is: {lotteryWinner}")
