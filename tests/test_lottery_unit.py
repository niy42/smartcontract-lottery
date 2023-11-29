from brownie import accounts, network, exceptions
from scripts.deploy_lottery import deploy_lot
from scripts.helpful import LOCAL_BLOCKCHAIN_ENVIRONMENT, get_account
from web3 import Web3
import pytest


def test_lottery_unit():
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENT:
        pytest.skip("Only for local testing")
    # Arrange
    lottery = deploy_lot()

    # Act
    expected_funded_amount = Web3.toWei("30", "ether")

    # Assert
    assert expected_funded_amount == lottery  # Test passed


def test_cant_call_only_owner():
    # Arrange
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENT:
        pytest.skip()

    # Act / Assert
    lottery = deploy_lot()  # deployed by get_account() --> operator/owner
    # Test passed, only operator/owner can call function startLottery
    with pytest.raises(exceptions.VirtualMachineError):
        lottery.startLottery(
            get_account(),  # operator/owner
            10,
            10,
            100,
            500000000000000000000,
            {
                "from": "0xF23FD61FE28FF06C9804CEB493ABEB1BD93CFBB4"
            },  # "0xF23FD61FE28FF06C9804CEB493ABEB1BD93CFBB4" wasnt the address that deployed the contract.
            # Thus, caller not operator
        )
