// SPDX-License-Identifier: MIT

import "./VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";

pragma solidity >=0.6.0 <0.9.0;

contract Lottery is VRFConsumerBaseV2 {
    /* --- VRFCOORDINATOR REQUEST ARGS ---- */
    uint32 subId;
    bytes32 keyHash;
    uint16 constant minimumRequestConfirmations = 3;
    uint32 constant callbackGasLimit = 100000;
    uint32 numWords = 2;

    uint32 s_subscriptionId;
    uint16 requestConfirmations = 3;

    /* -------* CHAINLINK ORACLE ADDRESSES *--------- */
    AggregatorV3Interface internal priceFeed;
    VRFCoordinatorV2Interface private immutable COORDINATOR;

    // state variables
    address payable public owner;
    uint256[] public s_randomWords;
    uint256 public s_requestId;
    address[] public funders;
    uint256 lotteryCount = 0;
    uint256[] public requestIds;

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

    //events
    event lotteryCreated(
        address lotteryOperator,
        uint256 operatorCommissionPercentage,
        uint256 maxTickets,
        uint256 ticketPrice,
        uint256 expiration
    );
    event ticketsBought(
        uint256 lotteryId,
        address buyer,
        uint256 numberOftickets
    );
    event requestLotteryWinnerSent(
        uint256 lotteryId,
        uint256 requestId,
        uint256 numWords
    );
    event logTicketCommission(
        uint256 lotteryId,
        uint256 lotteryOperator,
        uint256 amount
    );
    event lotteryClaimed(
        uint256 lotteryId,
        address lotteryWinner,
        uint256 amount
    );
    event requestFulfilled(uint256[] randomWords);
    event LotteryWinner(uint256 lotteryId, address lotteryWinner);

    mapping(uint256 => lotteryData) public lottery;
    mapping(uint256 => lotteryStatus) public s_request;

    //mapping(address => uint256) public balance;

    constructor(
        uint32 _subId,
        bytes32 _keyHash,
        address _priceFeed,
        address _vrfCoordinator
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
        address _lotteryOperator,
        uint256 _lotteryOperatorCommission,
        uint256 _maxTickets,
        uint256 _ticketPrice,
        uint256 _expiration
    ) public onlyOperator(lotteryCount) {
        require(_expiration > block.timestamp, "Error: lottery has expired");
        require(_lotteryOperator != address(0), "Error: Invalid Operator");
        require(
            _lotteryOperatorCommission > 0 &&
                _lotteryOperatorCommission % 5 == 0,
            "Error: must be greater than zero and a multiple of five"
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
        emit lotteryCreated(
            _lotteryOperator,
            _lotteryOperatorCommission,
            _maxTickets,
            _ticketPrice,
            _expiration
        );
    }

    function buyTickets(uint256 lotteryId, uint256 tickets) public payable {
        uint256 amount = msg.value;
        require(
            block.timestamp < lottery[lotteryId].expiration,
            "Error: lottery has expired!"
        );
        require(tickets > 0, "tickets must be greater than zero!");
        require(
            amount >= lottery[lotteryId].ticketPrice * tickets,
            "Error: amount must be greater or equal to ticketprice!"
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
        emit ticketsBought(lotteryId, msg.sender, tickets);
    }

    function endLottery(
        uint256 _lotteryId
    ) external onlyOperator(_lotteryId) returns (uint256) {
        require(
            lottery[_lotteryId].lotteryWinner == address(0),
            "Error: lottery winner has been selected"
        );
        // require(
        //     lottery[_lotteryId].expiration < block.timestamp,
        //    "Error: lottery has not expired!"
        // );
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
        emit requestLotteryWinnerSent(_lotteryId, s_requestId, numWords);
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
        address lotteryWinner = currentLottery.lotteryWinner;
        require(sentWinner, "Error: winner amount not sent!");
        emit lotteryClaimed(lotteryId, lotteryWinner, winnerAmount);
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
        emit LotteryWinner(_lotteryId, lotteryWinner);
        return lotteryWinner;
    }

    ///function fundme() external payable {
    //    balance[msg.sender] += msg.value;
    //    funders.push(msg.sender);
    //}

    //function withdraw(uint256 amount) public payable {
    //    require(balance[msg.sender] >= amount, "Error: insufficeient balance");
    //    balance[msg.sender] -= amount;
    //     (bool sent, ) = (msg.sender).call{value: amount}("");
    //     require(sent, "Error: amount not sent");
    //}

    receive() external payable {}

    fallback() external {}
}
