pragma solidity ^0.4.8;

interface IERC20{
    function totalSupply() constant returns (uint256 totalSupply);
    function balanceOf(address _owner) constant returns (uint256 balance);
    function transfer(address _to, uint256 _value) returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) returns (bool success);
    function approve(address _spender, uint256 _value) returns (bool success);
    function allowance(address _owner, address _spender) constant returns (uint256 remaining);
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    event FrozenFunds(address target, bool frozen);
}

library SafeMath {
  function mul(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal constant returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint256 a, uint256 b) internal constant returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}
// contract owned {
//     address public owner;

//     function owned() {
//         owner = msg.sender;
//     }

//     modifier onlyOwner {
//         if (msg.sender != owner) revert();
//         _;
//     }

//     function transferOwnership(address newOwner) onlyOwner {
//         owner = newOwner;
//     }
// }

contract sofoCoin is IERC20{
  
    using SafeMath for uint256;
      
     string public standard = 'Token 0.1';
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public _totalSupply=0;

    uint256 public sellPrice = 100000000000000000;// 1 eth = 10 token, 1 token =1/10 eth
    //uint256 public buyPrice;
    uint256 public constant RATE = 10;
    address public owner;
    
    mapping (address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowed;
    mapping (address => bool) public frozenAccount;
    address[] users;
    uint[] tokenNumber;
    
    
    event check(address add);
    
    function sofoCoin(  //uint256 initialSupply,
        string tokenName,
        uint8 decimalUnits,
        string tokenSymbol
        // uint256 sellPrice,
        // uint256 RATE
        ) {
        // //balances[msg.sender] = initialSupply;              
        // //_totalSupply = initialSupply;                        
        name = tokenName;                                   
        symbol = tokenSymbol;                               
        decimals = decimalUnits;
        owner = msg.sender;
        // sellPrice = sellPrice;
        // RATE = RATE;
    }
     modifier onlyOwner {
        if (msg.sender != owner) revert();
        _;
    }
    function totalSupply() constant returns (uint256 totalSupply){
        return totalSupply;
        
    }
    function balanceOf(address _owner) constant returns (uint256 balance){
        return balances[_owner];
    }
    
    function transfer(address _to, uint256 _value) returns (bool success){
        require(balances[msg.sender] >= _value && _value>0);
        if (frozenAccount[msg.sender]) revert();
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        Transfer(msg.sender,_to,_value);
        return true;
    }
    function transferFrom(address _from, address _to, uint256 _value) returns (bool success){
        if (frozenAccount[_from]) revert();
        require(allowed[_from][msg.sender] >= _value && balances[_from] >= _value && _value >0 );
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        Transfer(_from,_to,_value);
        return true;
        
    }
    function approve(address _spender, uint256 _value) returns (bool success){
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender,_spender,_value);
        return true;
        
    }
    function allowance(address _owner, address _spender) constant returns (uint256 remaining){
        return allowed[_owner][_spender];
    }
    //   function mintToken(address target, uint256 mintedAmount) onlyOwner {
    //     balances[target] += mintedAmount;
    //     _totalSupply += mintedAmount;
    //     Transfer(0, this, mintedAmount);
    //     Transfer(this, target, mintedAmount);
    // }

    function freezeAccount(address target, bool freeze) onlyOwner {
        frozenAccount[target] = freeze;
        FrozenFunds(target, freeze);
    }

    // function setPrices(uint256 newSellPrice, uint256 newBuyPrice) onlyOwner {
    //     sellPrice = newSellPrice;
    //     buyPrice = newBuyPrice;
    // }
    
    function() payable{
        requestToken();
    }
    
    function requestToken() payable{
        require(msg.value>0);
        uint256 tokens = msg.value.mul(RATE);
        balances[msg.sender] = balances[msg.sender].add(tokens);
        _totalSupply = _totalSupply.add(tokens);
        
            users.push(msg.sender);
            tokenNumber.push(tokens);
       
        owner.transfer(msg.value);
    }
    
     function readAllUsers()constant returns(address[]){
       return users;
      
   }

  
    function sell(uint256 amount) {
        if (balances[msg.sender] < amount ) revert();        
        balances[this] =balances[this].add(amount);                         
        balances[msg.sender] =balances[msg.sender].sub(amount);                   
        if (!msg.sender.send(amount * sellPrice)) {        
            revert();                                         
        } else {
            Transfer(msg.sender, this, amount);            
        }               
    }
    
}
