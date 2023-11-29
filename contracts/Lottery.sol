// SPDX-License-Identifier: MIT

import "./VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
pragma solidity ^0.8.22;

/*******************************************************************************
 *@title: LOTTERY.SOL
 *@author: OBANLA ADENIYI (niy42)
 *******************************************************************************
 *@note: a simple project lottery that can be incorporated into web3 lottery platforms and games.
 *@dev: The VRF configuration setting for this program is specifically built for Sepolia testnet.
 * If you choose to use any network other than Sepolia, ensure that the networks' configuration settings are properly set.
 */

contract Lottery is VRFConsumerBaseV2 {
    /*-----------------* STATE VARIABLES *------------------*/
    //VRFCoordinator config for Sepolia testnet
    // Your subscription ID.
    uint64 immutable s_subscriptionId;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    bytes32 immutable s_keyHash;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 constant CALLBACK_GAS_LIMIT = 100000;

    // The default is 3, but you can set this higher.
    uint16 constant REQUEST_CONFIRMATIONS = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 constant NUM_WORDS = 2;

    // contract addresses for realWorld data from an oracle(chainlink)
    AggregatorV3Interface internal priceFeed;
    VRFCoordinatorV2Interface private immutable COORDINATOR;

    // state variables
    address payable public owner;
    uint256 lotteryCount = 0;
    uint256 public s_requestId;
    uint256[] public s_randomWords;

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

    constructor(
        uint64 _subId,
        bytes32 _keyHash,
        address _priceFeed,
        address _vrfCoordinator
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        priceFeed = AggregatorV3Interface(_priceFeed);
        COORDINATOR = VRFCoordinatorV2Interface(_vrfCoordinator);
        s_subscriptionId = _subId;
        s_keyHash = _keyHash;
        owner = payable(msg.sender);
        lottery[lotteryCount].lotteryOperator = owner;
    }

    mapping(uint256 => lotteryData) public lottery; // lotteryId/lotteryCount mapped to lotteryData
    mapping(uint256 => lotteryStatus) public s_request; // requestId mapped to lotteryStatus

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
        uint256 lotteryWinner,
        uint256 amount
    );
    event requestFulfilled(uint256[] randomWords);
    event lotteryWinner(uint256 lotteryId, address lotteryWinner);

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

    function startLottery(
        address _lotteryOperator,
        uint256 _operatorCommissionPercentage,
        uint256 _maxTicket,
        uint256 _ticketPrice,
        uint256 _expiration
    ) public onlyOperator(lotteryCount) {
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
        lottery[lotteryCount++] = lotteryData({
            lotteryOperator: _lotteryOperator,
            operatorCommissionPercentage: _operatorCommissionPercentage,
            maxTicket: _maxTicket,
            ticketPrice: _ticketPrice,
            tickets: new address[](0),
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
        uint256 payment = msg.value;
        require(tickets > 0, "Error: tickets must be greater than zero");
        require(
            tickets <= getRemainingTickets(_lotteryId),
            "Error: tickets must be less than or equal to remaining tickets"
        );
        require(
            payment >= lottery[_lotteryId].ticketPrice * tickets,
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
        emit ticketsBought(_lotteryId, msg.sender, tickets);
    }

    function endLottery(uint256 _lotteryId) public onlyOperator(_lotteryId) {
        //require(
        // block.timestamp > lottery[_lotteryId].expiration,
        // "Error: lottery has not expired!"
        // );
        require(
            lottery[_lotteryId].lotteryWinner == address(0),
            "Error: lottery winner is not yet drawn!"
        );
        // Will revert if subscription is not set and funded.
        s_requestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_subscriptionId,
            REQUEST_CONFIRMATIONS,
            CALLBACK_GAS_LIMIT,
            NUM_WORDS
        );
        s_request[s_requestId] = lotteryStatus({
            lotteryId: _lotteryId,
            exist: true,
            fulfilled: false,
            randomNumbers: new uint256[](0)
        });
        emit requestLotteryWinnerSent(_lotteryId, s_requestId, NUM_WORDS);
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
        uint256 /* requestId */,
        uint256[] memory randomWords
    ) internal override {
        s_randomWords = randomWords;
        emit requestFulfilled(s_randomWords);
    }

    function DrawLotteryWinner(
        uint256 _lotteryId
    ) public onlyOperator(_lotteryId) returns (address _lotteryWinner) {
        uint256 indexOfWinner = s_randomWords[0] %
            lottery[_lotteryId].tickets.length;
        lottery[_lotteryId].lotteryWinner = lottery[_lotteryId].tickets[
            indexOfWinner
        ];
        _lotteryWinner = lottery[_lotteryId].lotteryWinner;
        emit lotteryWinner(_lotteryId, _lotteryWinner);
        return _lotteryWinner;
    }
}
