// SPDX-License-Identifier: MIT
import "./VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";

pragma solidity >=0.6.0 <0.9.0;

/*******************************************************************************
 *@title: LOTTERY.SOL
 *@author: OBANLA ADENIYI (niy42)
 *******************************************************************************
 *@note: a simple project lottery that can be incorporated into web3 lottery platforms and games.
 *@dev: The VRF configuration setting for this program is specifically built for Sepolia testnet.
 * If you choose to use any network other than Sepolia, ensure that the networks' configuration settings are properly set.
 */

contract Lottery is VRFConsumerBaseV2 {
    /* --- VRFCOORDINATOR REQUEST ARGS ---- */
    uint32 subId;
    bytes32 keyHash;
    uint16 constant minimumRequestConfirmations = 3;
    uint32 constant callbackGasLimit = 100000;
    uint32 numWords = 1;

    /* -------* CHAINLINK ORACLE ADDRESSES *--------- */
    AggregatorV3Interface internal priceFeed;
    VRFCoordinatorV2Interface private immutable COORDINATOR;

    // state variables
    address payable public owner;
    uint256[] public s_randomWords;
    address[] public funders;
    uint256 lotteryCount = 0;

    struct lotteryData {
        uint256 lotteryOperatorCommission;
        address lotteryOperator;
        address[] tickets;
        uint256 maxTickets;
        uint256 ticketPrice;
        uint256 expiration;
        address lotteryWinner;
    }

    struct lotteryStatus {
        uint256 lotteryId;
        bool exist;
        bool fulfilled;
        uint256[] randomNumbers;
    }

    mapping(uint256 => lotteryData) public lottery;
    mapping(uint256 => lotteryStatus) public s_request;
    mapping(address => uint256) public balance;

    constructor(
        uint32 _subId,
        address _vrfCoordinator,
        address _priceFeed,
        bytes32 _keyHash
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        priceFeed = AggregatorV3Interface(_priceFeed);
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
        keyHash = _keyHash;
        subId = _subId;
        owner = payable(msg.sender);
        lottery[lotteryCount].lotteryOperator = owner;
    }

    modifier onlyOperator(uint256 lotteryId) {
        require(
            msg.sender == lottery[lotteryId].lotteryOperator ||
                msg.sender == owner,
            "Error: call restricted to only operator!"
        );
        _;
    }
    modifier canCLaimLottery(uint256 lotteryId) {
        require(
            msg.sender == owner ||
                msg.sender == lottery[lotteryId].lotteryOperator ||
                msg.sender == lottery[lotteryId].lotteryWinner,
            "Error: call retricted to only owner!"
        );
        _;
    }

    /* ---------- FUNCTION DECLARATIONS AND DEFINITIONS ----------*/
    function getRemainingTickets(
        uint256 lotteryId
    ) public view returns (uint256) {
        return
            lottery[lotteryId].maxTickets - lottery[lotteryId].tickets.length;
    }

    function startLottery(
        uint256 _expiration,
        address _lotteryOperator,
        uint256 _lotteryOperatorCommission,
        uint256 _maxTickets,
        uint256 _ticketPrice
    ) public onlyOperator(lotteryCount) {
        require(_expiration > block.timestamp, "Error: lottery has expired");
        require(_lotteryOperator != address(0), "Error: Invalid Operator");
        require(
            _lotteryOperatorCommission > 0 &&
                _lotteryOperatorCommission % 5 == 0,
            "Error: operator commission must be greater than zero and a multiple of five"
        );
        require(
            _maxTickets > 0,
            "Error: maximum tickets must be greater than zero"
        );
        require(_ticketPrice > 0, "Error: ticket price must not be zero");
        lotteryCount;
        lottery[lotteryCount++] = lotteryData({
            lotteryOperator: _lotteryOperator,
            lotteryOperatorCommission: _lotteryOperatorCommission,
            maxTickets: _maxTickets,
            ticketPrice: _ticketPrice,
            expiration: _expiration,
            lotteryWinner: address(0),
            tickets: new address[](0)
        });
    }

    function BuyTickets(uint256 lotteryId, uint256 tickets) public payable {
        uint256 amount = msg.value;
        require(
            block.timestamp < lottery[lotteryId].expiration,
            "Error: lottery has expired!"
        );
        require(tickets > 0, "tickets must be greater than zero!");
        require(
            amount == lottery[lotteryId].ticketPrice * tickets,
            "Error: amount must equal price!"
        );
        require(
            tickets <= getRemainingTickets(lotteryId),
            "Error: tickets must be less than or equal to remaining tickets!"
        );

        uint256 i = 0;
        while (i < tickets) {
            lottery[lotteryId].tickets.push(msg.sender);
            ++i;
        }
    }

    function endLottery(
        uint256 _lotteryId
    ) external onlyOperator(_lotteryId) returns (uint256 s_requestId) {
        require(
            lottery[_lotteryId].lotteryWinner == address(0),
            "Error: lottery winner has been selected"
        );
        require(
            lottery[_lotteryId].expiration < block.timestamp,
            "Error: lottery has not expired!"
        );
        s_requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subId,
            minimumRequestConfirmations,
            callbackGasLimit,
            numWords
        );
        s_request[s_requestId] = lotteryStatus({
            lotteryId: _lotteryId,
            exist: true,
            fulfilled: false,
            randomNumbers: new uint256[](0)
        });
        return s_requestId;
    }

    function claimLottery(uint256 lotteryId) public {
        lotteryData storage currentLottery = lottery[lotteryId];
        uint256 vaultAmount;
        vaultAmount =
            currentLottery.tickets.length *
            currentLottery.ticketPrice;
        uint256 operatorCommission = vaultAmount /
            (100 / currentLottery.lotteryOperatorCommission);

        (bool sentCommission, ) = (currentLottery.lotteryOperator).call{
            value: operatorCommission
        }("");
        require(sentCommission, "Error: commission not sent!");

        uint256 winnerAmount = vaultAmount - operatorCommission;
        (bool sentWinner, ) = (currentLottery.lotteryWinner).call{
            value: winnerAmount
        }("");
        require(sentWinner, "Error: winner amount not sent!");
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal override {
        s_randomWords = randomWords;
    }

    function drawLotteryWinner(
        uint256 _lotteryId
    ) public onlyOperator(_lotteryId) returns (address lotteryWinner) {
        lotteryData storage currentLottery = lottery[_lotteryId];
        uint256 winnerIndex = s_randomWords[0] % currentLottery.tickets.length;
        currentLottery.lotteryWinner = currentLottery.tickets[winnerIndex];
        lotteryWinner = currentLottery.lotteryWinner;
        return lotteryWinner;
    }

    function fundme() external payable {
        balance[msg.sender] += msg.value;
        funders.push(msg.sender);
    }

    function withdraw(uint256 amount) public payable {
        require(balance[msg.sender] >= amount, "Error: insufficeient balance");
        balance[msg.sender] -= amount;
        (bool sent, ) = (msg.sender).call{value: amount}("");
        require(sent, "Error: amount not sent");
    }

    receive() external payable {
        // receives plain ETHER
    }

    fallback() external {}
}
