// SPDX-License-Identifier: MIT

import "./VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
pragma solidity ^0.8.22;

/*
 *@title: LOTTERY.SOL
 *@author: OBANLA ADENIYI (niy42)
 *@note: a simple project lottery that can be incorporated into web3 lottery platforms and games.
 *@note: The VRF configuration setting for this program is specifically built for Sepolia testnet.
 * If you are using any network other than Sepolia, ensure the networks' configurations are set properly.
 */

contract Lottery is VRFConsumerBaseV2 {
    /*-----------------* STATE VARIABLES *------------------*/
    //VRFCoordinator config for Sepolia testnet
    bytes32 keyHash =
        0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
    uint64 subId;
    address vrfCoordinator = 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625;
    uint16 minimumRequestConfirmations;
    uint32 callbackGasLimit = 300000;
    uint32 numWords = 1;

    // contract addresses for realWorld data from an oracle(chainlink)
    AggregatorV3Interface internal priceFeed;
    VRFCoordinatorV2Interface private immutable COORDINATOR;

    // state variables
    address payable public owner;
    uint256 lotteryCount = 0;

    struct lotteryData {
        address lotteryOperator;
        uint256 operatorCommissionPercentage;
        uint256 ticketPrice;
        uint256 maxTicket;
        address[] tickets;
        uint256 expiration;
        address lotteryWinner;
    }
    struct lotteryStatus {
        uint256 lotteryId;
        bool fulfilled;
        bool exist;
        uint256[] randomNumbers;
    }

    constructor(uint64 _subId) VRFConsumerBaseV2(vrfCoordinator) {
        priceFeed = AggregatorV3Interface(
            0x694AA1769357215DE4FAC081bf1f309aDC325306
        );
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        subId = _subId;
    }

    mapping(uint256 => lotteryData) public lottery; // lotteryId and lotteryCount mapped to lotteryData
    mapping(uint256 => lotteryStatus) public s_request; // requestId mapped to lotteryStatus

    //events
    event lotteryCreated(
        address lotteryOperator,
        uint256 operatorCommissionPercentage,
        uint256 maxTickets,
        uint256 ticketPrice,
        uint256 expiration
    );
    event ticketBoughts(
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
        uint256 lotteryWinner,
        uint256 amount
    );
    event requestFulfilled(
        uint256 lotteryId,
        uint256 requestId,
        uint256 randomWords
    );
    event lotteryWinner(
        uint256 lotteryId,
        address lotteryWinner,
        uint256 lotteryAmount
    );

    /* --------------* MODIFIERS *--------------- */
    modifier onlyOperator(uint256 _lotteryId) {
        require(
            msg.sender == lottery[_lotteryId].lotteryOperator ||
                msg.sender == owner,
            "Error: call restricted to only operator!"
        );
        _;
    }
    modifier canClaimLottery(uint256 _lotteryId) {
        require(msg.sender != address(0), "");
        require(
            msg.sender == lottery[_lotteryId].lotteryOperator ||
                msg.sender == lottery[_lotteryId].lotteryWinner ||
                msg.sender == owner,
            "Error: Only winner can claim reward!"
        );
        _;
    }

    /* -------------------* FUNCTION DECLARATIONS AND DEFINITIONS *-----------------------*/
    function getRemainingTickets(
        uint256 _lotteryId
    ) public view returns (uint256) {
        lotteryData storage currentLottery = lottery[_lotteryId];
        return currentLottery.maxTicket - currentLottery.tickets.length;
    }

    function startLottey(
        address _lotteryOperator,
        uint256 _operatorCommissionPercentage,
        uint256 _maxTicket,
        uint256 _ticketPrice,
        uint256 _expiration
    ) public {
        require(
            _lotteryOperator != address(0),
            "Error: lottery operator cannot be 0x0!"
        );
        require(
            _operatorCommissionPercentage > 0 &&
                _operatorCommissionPercentage % 5 == 0,
            "Error: operatorCommissionPercentage must be greater than zero and a multiple of 5"
        );
        require(_maxTicket > 0, "Error: ticket max must be greater than zero");
        require(
            _ticketPrice > 0,
            "Error: ticket price must be greater than zero"
        );
        require(block.timestamp < _expiration, "Error: Lottery as expired");
        address[] memory ticketArray;
        lotteryCount++;
        lottery[lotteryCount] = lotteryData({
            lotteryOperator: _lotteryOperator,
            operatorCommissionPercentage: _operatorCommissionPercentage,
            maxTicket: _maxTicket,
            ticketPrice: _ticketPrice,
            tickets: ticketArray,
            lotteryWinner: address(0),
            expiration: _expiration
        });
        emit lotteryCreated(
            _lotteryOperator,
            _operatorCommissionPercentage,
            _maxTicket,
            _ticketPrice,
            _expiration
        );
    }

    function BuyTickets(uint256 _lotteryId, uint256 tickets) public payable {
        uint256 amount = msg.value;
        require(tickets > 0, "Error: tickets must be greater than zero");
        require(
            tickets <= getRemainingTickets(_lotteryId),
            "Error: tickets must be less than or equal to remaining tickets"
        );
        require(
            amount >= lottery[_lotteryId].ticketPrice,
            "Error: amount must equal price"
        );
        require(
            lottery[_lotteryId].expiration > block.timestamp,
            "Error: lottery has expired!"
        );
        lotteryData storage currentLottery = lottery[_lotteryId];
        uint256 i = 0;
        while (i < tickets) {
            currentLottery.tickets.push(msg.sender);
            ++i;
        }
        emit ticketBoughts(_lotteryId, msg.sender, tickets);
    }

    function endLottery(uint256 _lotteryId) public returns (uint256 requestId) {
        require(
            lottery[_lotteryId].lotteryWinner == address(0),
            "Error: lottery winner has been drawn"
        );
        require(
            block.timestamp > lottery[_lotteryId].expiration,
            "Error: lottery has not expired yet!"
        );
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subId,
            minimumRequestConfirmations,
            callbackGasLimit,
            numWords
        );
        s_request[requestId] = lotteryStatus({
            lotteryId: _lotteryId,
            exist: true,
            fulfilled: false,
            randomNumbers: new uint256[](0)
        });
        emit requestLotteryWinnerSent(_lotteryId, requestId, numWords);
        return requestId;
    }

    function claimLottery(
        uint256 _lotteryId
    ) public canClaimLottery(_lotteryId) returns (uint256 winnerAmount) {
        lotteryData storage currentLottery = lottery[_lotteryId];
        uint256 vaultAmount = currentLottery.ticketPrice *
            currentLottery.tickets.length;
        uint256 operatorCommission = vaultAmount /
            (100 / currentLottery.operatorCommissionPercentage);
        (bool sentCommission, ) = payable(currentLottery.lotteryOperator).call{
            value: operatorCommission
        }("");
        require(sentCommission, "Error: commission not sent");

        winnerAmount = vaultAmount - operatorCommission;
        (bool sentWinner, ) = payable(currentLottery.lotteryWinner).call{
            value: winnerAmount
        }("");
        require(sentWinner, "Error: reward not sent!");
        return winnerAmount;
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        require(s_request[requestId].exist, "Error: No response");
        uint256 lotteryId = s_request[requestId].lotteryId;
        s_request[requestId].fulfilled = true;
        s_request[requestId].randomNumbers = randomWords;
        uint256 indexOfWinner = randomWords[0] %
            lottery[lotteryId].tickets.length;
        lottery[lotteryId].lotteryWinner = lottery[lotteryId].tickets[
            indexOfWinner
        ];
        uint256 winnerAmount = claimLottery(lotteryId);
        emit requestFulfilled(lotteryId, requestId, randomWords[0]);
        emit lotteryWinner(
            lotteryId,
            lottery[lotteryId].lotteryWinner,
            winnerAmount
        );
    }
}
