// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract OpenAuction {
    address public seller;
    address public highestBidder;
    uint public highestBid;
    uint public auctionEndTime;
    uint public auctionExtensionTime = 5 minutes; // Auction extension time
    uint public biddingCooldown = 1 minutes; // Bidding cooldown period
    mapping(address => uint) public pendingReturns;
    mapping(address => uint) public lastBidTime;

    bool ended;

    event HighestBidIncreased(address bidder, uint amount);
    event AuctionEnded(address winner, uint amount);

    constructor(uint _biddingTime) {
        seller = msg.sender;
        auctionEndTime = block.timestamp + _biddingTime;
    }

    function bid() external payable {
        require(block.timestamp <= auctionEndTime, "Auction has ended");
        require(msg.value > highestBid, "Bid is lower than current highest bid");
        require(
            lastBidTime[msg.sender] + biddingCooldown <= block.timestamp,
            "Bidding cooldown period not yet finished"
        );

        if (highestBid != 0) {
            pendingReturns[highestBidder] += highestBid;
        }

        // Calculate bid weight
        uint weight = calculateBidWeight();
        uint weightedBid = msg.value * weight;

        highestBidder = msg.sender;
        highestBid = weightedBid;
        lastBidTime[msg.sender] = block.timestamp;
        emit HighestBidIncreased(msg.sender, msg.value);

        // If bidding happens in the last few minutes of the auction, extend the auction time
        if (block.timestamp + 5 minutes >= auctionEndTime) {
            auctionEndTime += auctionExtensionTime;
        }
    }

    function calculateBidWeight() internal view returns (uint) {
        if (auctionEndTime <= block.timestamp + 5 minutes) {
            return 2; // In the last 5 minutes, the bid weight is doubled
        }
        return 1; // Normal bid weight is 1
    }

    function withdraw() external returns (bool) {
        uint amount = pendingReturns[msg.sender];
        require(amount > 0, "No bids to withdraw");

        pendingReturns[msg.sender] = 0;

        if (!payable(msg.sender).send(amount)) {
            pendingReturns[msg.sender] = amount;
            return false;
        }
        return true;
    }

    function endAuction() external {
        require(block.timestamp >= auctionEndTime, "Auction not yet ended");
        require(!ended, "Auction has already ended");

        ended = true;
        emit AuctionEnded(highestBidder, highestBid);

        payable(seller).transfer(highestBid);
    }
}