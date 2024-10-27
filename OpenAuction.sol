// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract OpenAuction {
    address public seller;
    address public highestBidder;
    uint public highestBid;
    uint public auctionEndTime;
    uint public auctionExtensionTime = 5 minutes; // 拍卖终局延长时间
    uint public biddingCooldown = 1 minutes; // 出价冷却期
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
        require(block.timestamp <= auctionEndTime, "拍卖已结束");
        require(msg.value > highestBid, "出价低于当前最高出价");
        require(
            lastBidTime[msg.sender] + biddingCooldown <= block.timestamp,
            "出价冷却期未结束"
        );

        if (highestBid != 0) {
            pendingReturns[highestBidder] += highestBid;
        }

        highestBidder = msg.sender;
        highestBid = msg.value;
        lastBidTime[msg.sender] = block.timestamp;
        emit HighestBidIncreased(msg.sender, msg.value);

        // 如果在拍卖结束前的最后几分钟内出价，延长拍卖时间
        if (block.timestamp + 5 minutes >= auctionEndTime) {
            auctionEndTime += auctionExtensionTime;
        }
    }

    function withdraw() external returns (bool) {
        uint amount = pendingReturns[msg.sender];
        require(amount > 0, "没有待退还的出价");

        pendingReturns[msg.sender] = 0;

        if (!payable(msg.sender).send(amount)) {
            pendingReturns[msg.sender] = amount;
            return false;
        }
        return true;
    }

    function endAuction() external {
        require(block.timestamp >= auctionEndTime, "拍卖还未结束");
        require(!ended, "拍卖已结束");

        ended = true;
        emit AuctionEnded(highestBidder, highestBid);

        payable(seller).transfer(highestBid);
    }
}
