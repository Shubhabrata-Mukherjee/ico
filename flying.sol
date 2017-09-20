pragma solidity ^0.4.11;

contract token { function transfer(address receiver, uint amount);
                 function mintToken(address target, uint mintedAmount);
                 function balanceOfUser(address userAddress);  // send address of user to get balance OR use 'this' to get balance of msg.sender
                 function freezeAccount(address target, bool freeze);
                }

contract FlyingCashICO {
    enum State {
        Fundraising,
        Failed,
        Successful,
        Closed
    }
    State public state = State.Fundraising;

    struct Contributors {
        address contributor;
        uint amountInWei;
        uint excessAmountInWei;
        uint totalToken;
        uint rateInWei;
        uint freezeTime;        
        bool finalized;
        bool freezeStatus;    
        bool excessEtherRefunded;             
    }
    Contributors[] contributorsArray;    

    struct PriceList
    {
        uint256 fromRange;
        uint256 toRange;
        uint256 price;
    }    
    PriceList[] priceArray;
    
    uint public totalTokenTransfered;
    uint public totalTransferableTokens;
    uint public totalRaised;
    uint public currentBalance;
    //uint public totalBalanceAfterExcessDedection;
    uint public deadline;
    uint public completedAt;
    uint public priceInWei;
    uint public fundingMinimumTargetInWei; 
    uint public fundingMaximumTargetInWei; 
    token public tokenReward;
    address public creator;
    address public beneficiary; 
    string campaignUrl;
    string constant version = "1.0";

    
    event LogFundingReceived(address addr, uint amount, uint currentTotal);
    event LogWinnerPaid(address winnerAddress);
    event LogFundingSuccessful(uint totalRaised);
    event TestEvent(uint totalEther, uint totalPrice);
    event LogFunderInitialized(
        address creator,
        address beneficiary,
        string url,
        uint _fundingMaximumTargetInEther, 
        uint256 deadline
        );


    modifier inState(State _state) {
        require(state == _state);        
         _;
    }

     modifier isMinimum() {
        require(msg.value >= priceInWei);        
        _;
    }

    modifier inMultipleOfPrice() {
        require(msg.value%priceInWei == 0);        
        _;
    }

    modifier isCreator() {
        require(msg.sender == creator);        
        _;
    }

    modifier isPriceConfigured() {
        require(priceArray.length !=0 );
        _;
    }

    
    modifier atEndOfLifecycle() {        
        require((state == State.Failed || state == State.Successful) && completedAt + 1 hours < now);
        _;
    }

    
    function FlyingCashICO(
        uint _timeInMinutesForFundraising,
        string _campaignUrl,
        address _ifSuccessfulSendTo,
        uint _fundingMinimumTargetInEther,
        uint _fundingMaximumTargetInEther,
        token _addressOfTokenUsedAsReward
        /*uint _etherCostOfEachToken*/) {
        creator = msg.sender;
        beneficiary = _ifSuccessfulSendTo;
        campaignUrl = _campaignUrl;
        fundingMinimumTargetInWei = _fundingMinimumTargetInEther * 1 ether; 
        fundingMaximumTargetInWei = _fundingMaximumTargetInEther * 1 ether; 
        deadline = now + (_timeInMinutesForFundraising * 1 minutes);
        currentBalance = 0;
        tokenReward = token(_addressOfTokenUsedAsReward);
        //priceInWei = _etherCostOfEachToken * 1 ether;
        priceInWei = 0;
        totalTokenTransfered = 0;         
        totalTransferableTokens = 0;       
        LogFunderInitialized(creator, beneficiary, campaignUrl, fundingMaximumTargetInWei, deadline);
    }

    function priceConfiguration(/*uint _fromRange,*/ uint _toRange, uint _priceInWei) public isCreator() 
                                returns (uint fromRange, uint toRange, bool priceChanged) {
        // price should be in Wei;
        uint _fromRange;
        //uint _
        if(priceArray.length != 0)
            _fromRange = priceArray[priceArray.length-1].toRange+1;        
        else        
            _fromRange = 0;   
        
        if(_fromRange < _toRange)
        {
            priceArray.push(
                PriceList({
                    fromRange: _fromRange,
                    toRange: _toRange,
                    price: _priceInWei
                })
            ); 
            return (_fromRange, _toRange, true);   
        }
    }

    function priceModify(uint _toRange, uint newPriceInWei) public isCreator() 
                        returns (uint fromRange, uint toRange, uint newPrice){
        // newPrice should be in Wei
        for(uint i=0; i<priceArray.length; i++)
        {
            if(priceArray[i].toRange == _toRange) {                
                priceArray[i].price = newPriceInWei;
                return (priceArray[i].fromRange, priceArray[i].toRange, priceArray[i].price);  
            }                        
        }
        return (0,0,0);
    }

    //function setCurrentPrice(uint256 currentPrice, uint256 currentBalance) isPriceConfigured() returns(bool) 
    function setCurrentPrice() isPriceConfigured() returns(bool priceChangeStatus) 
    {
        priceChangeStatus = false;
        if(totalTransferableTokens != 0)
        {
            for(uint i=0; i<priceArray.length; i++)
            {
                if(priceArray.length == i+1) 
                {   
                    priceInWei = priceArray[i+1].price;
                    priceChangeStatus = true;
                    break;
                }
                if(totalTransferableTokens >= priceArray[i].toRange) 
                {
                    //i++;
                    priceInWei = priceArray[i+1].price;
                    priceChangeStatus = true;
                    break;
                    //return true;                                                    
                }  
            } 
            //return false; 
        }
        else
        {               
            priceInWei = priceArray[0].price;
            priceChangeStatus = true;
        }
        return priceChangeStatus;
    }    

    //function checkForPriceChange(uint256 currentPrice, uint256 currentBalance) constant returns(bool)
    function checkForPriceChange() constant returns(bool)
    {
        for(uint i=0; i<priceArray.length; i++)
        {
            if(priceArray.length == i+1) 
            {   
                return false;
            }
            if(totalTransferableTokens >= priceArray[i].toRange || contributorsArray.length == 0 || priceInWei == 0)
            {
                return true;     
            }     
        }
        return false;   
    } 

    // function for get the Range Value at given price
    function getPriceRange(uint _priceInWei) constant returns(uint toRange, uint fromRange) 
    {
        for(uint i=0; i<priceArray.length; i++)
        {         
            if(priceArray[i].price == _priceInWei) 
            {
                return (priceArray[i].fromRange, priceArray[i].toRange);     
            }          
        }
        return (0,0);   
    }

    function calculateSplitCase(uint _amountInWei) constant returns (bool)
    {
        uint numberOfTokens = 0;        
        uint upperRangeOfCurrentPrice = 0;
        uint totalTokens = 0; //totalTransferableTokens + numberOfTokens;              

        ( , upperRangeOfCurrentPrice) = getPriceRange(priceInWei);

        numberOfTokens = _amountInWei / priceInWei;
        totalTokens = totalTransferableTokens + numberOfTokens; 
        if(upperRangeOfCurrentPrice < totalTokens)
        {
            return true;
        }
        return false;
    }

    function findNextPrice(uint _currentPrice) constant returns(uint nextPrice)
    {
        for(uint i=0; i<priceArray.length; i++)
        {
            if(priceArray.length == i+1) 
            {   
                return priceArray[i].price;
            }
            if(_currentPrice == priceArray[i].price)
            {
                return priceArray[i+1].price;     
            }             
        }
    } 

    function contribute(/*uint finalizationTimeInMinute*/) public inState(State.Fundraising) isMinimum() /*inMultipleOfPrice()*/ isPriceConfigured() payable 
                        returns (address contributor, uint tokenRecieved, uint atPrice, bool contributeStatus)
    {
        uint amountInWei;
        uint numberOfTokens;
        uint excessEther;
        bool priceChangeStatus = false;
        bool exEthRef = false;

        if(checkForPriceChange())
        {
            priceChangeStatus = setCurrentPrice();  
            if(priceChangeStatus != true)
            {
                return (msg.sender,0,0,false);
            }
        }

        //calculateSplitTokens();

        // if(priceChangeStatus != true)
        // {
        //     return 0;
        // }
        
        amountInWei = msg.value;

        if(calculateSplitCase(amountInWei))
        {
            uint nextPrice;
            nextPrice = findNextPrice(priceInWei);  
            numberOfTokens = amountInWei / nextPrice;
            excessEther = amountInWei % nextPrice;   
            if(excessRefund(msg.sender, excessEther))
            {
                exEthRef = true;
            }

            totalRaised += amountInWei - excessEther;
            currentBalance = totalRaised;
            totalTransferableTokens += numberOfTokens;
            contributorsArray.push(
                Contributors({
                    contributor: msg.sender,
                    amountInWei: msg.value,
                    excessAmountInWei: excessEther,
                    totalToken: numberOfTokens,
                    rateInWei: nextPrice,
                    freezeTime:  0,                
                    finalized: false,
                    freezeStatus: false,
                    excessEtherRefunded: exEthRef
                }) 
            );       
        }
        else
        {
            numberOfTokens = amountInWei / priceInWei;
            excessEther = amountInWei % priceInWei;
            if(excessRefund(msg.sender, excessEther))
            {
                exEthRef = true;
            }

            totalRaised += amountInWei - excessEther;
            currentBalance = totalRaised;
            totalTransferableTokens += numberOfTokens;
            contributorsArray.push(
                Contributors({
                    contributor: msg.sender,
                    amountInWei: msg.value,
                    excessAmountInWei: excessEther,
                    totalToken: numberOfTokens,
                    rateInWei: priceInWei,
                    freezeTime:  0,                
                    finalized: false,
                    freezeStatus: false,
                    excessEtherRefunded: exEthRef
                }) 
            );
        }
        
        
        //(numberOfTokens, excessEther) = calculateSplitTokens(amountInWei);
        
        //numberOfTokens = amountInWei / priceInWei;
        //excessEther = amountInWei % priceInWei;

        /*if(excessRefund(msg.sender, excessEther))
        {
            exEthRef = true;
        }

        totalRaised += amountInWei - excessEther;
        currentBalance = totalRaised;
        totalTransferableTokens += numberOfTokens;
        //totalBalanceAfterExcessDedection = totalBalanceAfterExcessDedection + (numberOfTokens * priceInWei);
        
        contributorsArray.push(
            Contributors({
                contributor: msg.sender,
                amountInWei: msg.value,
                excessAmountInWei: excessEther,
                totalToken: numberOfTokens,
                rateInWei: priceInWei,
                freezeTime:  0,                
                finalized: false,
                freezeStatus: false,
                excessEtherRefunded: exEthRef
                }) 
            );
        //totalTokenTransfered += numberOfTokens;*/
        LogFundingReceived(msg.sender, msg.value, totalRaised);        
        checkIfFundingCompleteOrExpired();

        return (msg.sender, numberOfTokens, priceInWei, true); 
    }

    function finaliseContributions() returns (uint numberOfFinalized, uint remainingForFinalization) {
        //uint numberOfFinalized = 0;
        for(uint i = 0; i <= contributorsArray.length; i++) 
        {
            //if(contributorsArray[i].finalizationTime + 1 <= now && contributorsArray[i].finalized == false ) {
                //totalRaised += contributorsArray[i].amount;
                //currentBalance = totalRaised;
                
                //contributorsArray[i].finalized = true;
                //numberOfFinalized++;      
                if(fundingMaximumTargetInWei != 0) 
                {                        
                    tokenReward.transfer(contributorsArray[i].contributor, contributorsArray[i].totalToken);                     
                    tokenReward.freezeAccount(contributorsArray[i].contributor, true);
                    contributorsArray[i].freezeStatus = true;
                    contributorsArray[i].freezeTime = now;
                    totalTokenTransfered += contributorsArray[i].totalToken;

                    contributorsArray[i].finalized = true;
                    numberOfFinalized++;  
                }
                else
                {
                    tokenReward.mintToken(contributorsArray[i].contributor, contributorsArray[i].totalToken); 
                    tokenReward.freezeAccount(contributorsArray[i].contributor, true);
                    contributorsArray[i].freezeStatus = true;
                    contributorsArray[i].freezeTime = now;
                    totalTokenTransfered += contributorsArray[i].totalToken;

                    contributorsArray[i].finalized = true;
                    numberOfFinalized++;  
                }
                //tokenReward.transfer(contributorsArray[i].contributor, contributorsArray[i].amount / priceInWei); 
                //totalTokenTransfered = contributorsArray[i].amount / priceInWei;
                //tokenReward.transfer(contributorsArray[i].contributor, contributorsArray[i].amount / contributorsArray[i].rateInWei);         
            //}            
        }
        remainingForFinalization = contributorsArray.length - numberOfFinalized;
        return (numberOfFinalized, remainingForFinalization);
    }

    function unfreezeAccount(address _accountAddress) isCreator() returns (bool)
    {
        uint arrayIndex;
        bool foundStatus;        
        (,,arrayIndex,foundStatus) = findContributors(_accountAddress);
        if(foundStatus)
        {
            tokenReward.freezeAccount(_accountAddress, false);
            contributorsArray[arrayIndex].freezeStatus = false;
            return true;
        }
        return false;
    } 

    function checkIfFundingCompleteOrExpired() {        
       
        if (fundingMaximumTargetInWei != 0 && totalRaised > fundingMaximumTargetInWei) {
            state = State.Successful;
            LogFundingSuccessful(totalRaised);
            payOut();
            completedAt = now;            
        } 
        else if ( now > deadline ) {
            if(totalRaised >= fundingMinimumTargetInWei) {
                state = State.Successful;
                LogFundingSuccessful(totalRaised);
                payOut();  
                completedAt = now;
            }
            else {
                state = State.Failed; 
                completedAt = now;
            }
        }       
    }

    function payOut() public inState(State.Successful) {
        require(beneficiary.send(this.balance));
        state = State.Closed;
        currentBalance = 0;
        LogWinnerPaid(beneficiary);
    }

    function getRefund() public inState(State.Failed) returns (bool) {
        for(uint i=0; i<=contributorsArray.length; i++) {
            if(contributorsArray[i].contributor == msg.sender) {
                uint amountToRefund = contributorsArray[i].amountInWei - contributorsArray[i].excessAmountInWei;
                uint tokens = contributorsArray[i].totalToken;
                contributorsArray[i].amountInWei = 0;       
                contributorsArray[i].totalToken = 0;         
                if(!contributorsArray[i].contributor.send(amountToRefund)) {
                    contributorsArray[i].amountInWei = amountToRefund + contributorsArray[i].excessAmountInWei;
                    contributorsArray[i].totalToken = tokens;
                    return false;
                }
                else {
                    totalRaised -= amountToRefund;
                    currentBalance = totalRaised;
                }
                return true;
            }
        }
        return false;
    }
        
    function findContributors(address _contributor) constant returns (address contributor, uint amount, uint index, bool status) {
        for(uint i=0; i<contributorsArray.length; i++) {
            if(contributorsArray[i].contributor == _contributor) {
                index = i-1;
                return (contributorsArray[i].contributor, contributorsArray[i].totalToken, index, true);
            }            
        }
        return(_contributor,0,0,false);
    }

     function excessRefund(address _userAddress, uint _excessAmount) public returns (bool) 
     {              
        if(!_userAddress.send(_excessAmount)) 
        {                    
            return false;
        }
        else 
        {
            return true;
        }
    }
        

    function removeContract() public isCreator() atEndOfLifecycle() {
        selfdestruct(msg.sender);            
    }

    function () { revert(); }
}

//60,"www","0x14723a09acff6d2a60dcdf7aa4aff308fddc160c",100,150,"0x000001325487"

