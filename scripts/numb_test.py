from scripts.deploy_lottery import deploy_lottery
import time


def numb():
    lottery = deploy_lottery()
    time.sleep(2)
    print("Amount Funded is: ", lottery)


def main():
    numb()
