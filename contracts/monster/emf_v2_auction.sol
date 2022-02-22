// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract MineAuction {
    event Bid(uint amount, uint tokenId);

    IERC20 public acceptableToken;
    IERC721 public mms2;

    uint public phrase;  // 1 - started/free bid, 2 - bid then extend
    uint public phraseOneEndAt;
    uint public endedAt;  // extend timestamp for last biding in phrase 2
    bool public ended;
    address public highestBidder;
    address public owner;
    address public target;
    uint public highestBid;
    uint public bidInc;
    uint public tokenId;
    uint public phraseOneDelay;
    uint public phraseTwoDelay;

    constructor(address _a, address _m, uint _startingBid, uint _bidInc) {
        owner = msg.sender;
        acceptableToken = IERC20(_a);
        mms2 = IERC721(_m);

        highestBid = _startingBid;
        bidInc = _bidInc;

        // note: for testnet only
        phraseOneDelay = 5 minutes;
        phraseTwoDelay = 1 minutes;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        // Underscore is a special character only used inside
        // a function modifier and it tells Solidity to
        // execute the rest of the code.
        _;
    }

    modifier validAddress(address _addr) {
        require(_addr != address(0), "Not valid address");
        _;
    }

    function bid(uint _charType, uint _tokenId, uint _amount) external {
        require(ended == false, "auc ended - ended");
        require(_amount >= highestBid + bidInc, "value < highest");
        if (_charType == 3) {
            if (msg.sender != mms2.ownerOf(_tokenId)) {
                revert("");
            }
        } else {
            //
        }
        require(msg.sender == mms2.ownerOf(_tokenId), "wrong ownner");  // todo: address cannot change tokenId

        if (phrase == 0) {  // start and go into phrase 1
            phrase = 1;
            phraseOneEndAt = block.timestamp + phraseOneDelay;
        } else if (phrase == 1) {
            if (block.timestamp > phraseOneEndAt) {
                if (block.timestamp <= phraseOneEndAt + phraseTwoDelay) {  // if new bid time in oneendat and first twodelay, then enter 2 phrase
                    phrase = 2;
                    endedAt = block.timestamp + phraseTwoDelay;
                } else {  // 
                    ended = true;
                    revert("auc ended - expired 1");
                }
            }
        } else if (phrase == 2) {
            // require(block.timestamp < endedAt, "auc ended - ended");
            if (block.timestamp > endedAt) {
                ended = true;
                revert("auc ended - expired 2");
            }
            endedAt = block.timestamp + phraseTwoDelay;
        } else {
            revert("illegal phrase");
        }

        acceptableToken.transferFrom(msg.sender, address(this), _amount);  // get this bid first
        if (highestBidder != address(0)) {
            acceptableToken.transfer(highestBidder, highestBid);  // send back to last bidder
        }

        highestBidder = msg.sender;
        highestBid = _amount;
        tokenId = _tokenId;

        // emit Bid(msg.sender, msg.value);
    }

    function isAuctionEnd() public view returns (bool, uint, address, uint, uint) {  // pure observer mode
        if (phrase == 1) {
            if (block.timestamp > phraseOneEndAt + phraseTwoDelay) {
                return (true, phrase, highestBidder, highestBid, tokenId);
            }
        } else if (phrase == 2) {
            if (block.timestamp > endedAt) {
                return (true, phrase, highestBidder, highestBid, tokenId);
            }
        }

        return (false, phrase, highestBidder, highestBid, tokenId);
    }

    function setTarget(address _t) external onlyOwner validAddress(_t) {
        target = _t;
    }

    function withdraw() external onlyOwner {
        require(target != address(0), "invalid target");
        // require(ended == true, "auc not ended");
        (bool auctionEnd, uint p, address hbr, uint hb, uint t) = isAuctionEnd();
        if (auctionEnd == false) {
            if (p == 0) {
                revert("auc not started");
            } else {
                revert("auc still running");
            }
        }

        acceptableToken.transferFrom(address(this), target, highestBid);
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint);

    function balanceOf(address account) external view returns (uint);

    function transfer(address recipient, uint amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
}

interface IERC165 {
    function supportsInterface(bytes4 interfaceID) external view returns (bool);
}

interface IERC721 is IERC165 {
    function balanceOf(address owner) external view returns (uint balance);

    function ownerOf(uint tokenId) external view returns (address owner);

    function safeTransferFrom(
        address from,
        address to,
        uint tokenId
    ) external;

    function safeTransferFrom(
        address from,
        address to,
        uint tokenId,
        bytes calldata data
    ) external;

    function transferFrom(
        address from,
        address to,
        uint tokenId
    ) external;

    function approve(address to, uint tokenId) external;

    function getApproved(uint tokenId) external view returns (address operator);

    function setApprovalForAll(address operator, bool _approved) external;

    function isApprovedForAll(address owner, address operator)
        external
        view
        returns (bool);
}