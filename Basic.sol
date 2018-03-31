pragma solidity ^0.4.19;

contract Basic {
    address public owner;
    uint256 public a = 10;
    uint256 public b;  // default 0, when without initial
    uint256 internal c = 2;
    uint256 private balance;
    
    function getBalance() public view returns(uint256 _balance){
        return balance;
    }
    
    function getBalanceEther() public view returns(uint256 _ether){
        return (balance/POW(10, 18));
    }
    
    function POW(uint256 bottom, uint256 pow) public pure returns(uint256){
        uint256 result = 1;
        for(uint i=0; i<pow; i++){
            result *= bottom;
        }
        
        return result;
    }
    
    // sample function, return type, pure, public
    function helloWorld() public pure returns (string) {
        return "HelloWorld!";
    }

    // sample Constructor function, no Visibility {external, public, internal, private}
    function Basic() public {
        owner = msg.sender;
        
    }
    function myfunc(){
        a = block.number;
    }

    // sample function2, return type, view 
    function returnOwner() public view returns(address) {
        return owner;
    }
    
    // sample function3, using global variable, Math Operations
    function add() public view returns(uint256) {
        return a + b;  // try +, -, *, /, %, **
    }
    
    // sample function4, input, _arg, setter
    function setB(uint256 _b) public returns(uint256) { // 직접 tx 를 받앙아야 발생한하는 함수. 
        b = _b;
        return b;
    }
    
    // sample function5, multi inputs, pure
    function add(uint256 _a, uint256 _b) public pure returns(uint256) {
        return _a + _b;
    }
    
    // sample function6, getter
    function getC() public view returns(uint256 _c) {
        return c;
    }
    
    // sample function7, internal function, Math Operations
    function internalFunction() internal view returns(uint256) {
        return a ** c;
    }

    // sample function8, call internal function
    function callInternal() public view returns(uint256) {
        return internalFunction();
    }
    
    // sample event, overloading
    event Logging(string logs);
    event Logging(uint256 logs);

/**
 * use web3.js to define callback (eventually eventhandler) function.
 * event is deployed in smart contract. But callback funtion do not belong to smart contract.
 * 
 * */
    event MyEvent(string msg);    
    
    // sample callback function, payable, no Visibility {external, public, internal, private}
    function() public payable {
        c = 5; 
        balance = msg.value;
        Logging(helloWorld());  // emit Logging(log); from pragma solidity ^0.4.21
        Logging(msg.value);
    }

    // sample modifier
    modifier makeLog() {
        Logging("start modifier");
        _;  // <- entry point
        Logging("end modifier");
    }
    
    // sample function for check how modifier work 
    function checkModifier() public makeLog {
        // Logging("start modifier");  // by modifier
        Logging("Logging in function");  // _;  entry point
        // Logging("end modifier");  // by modifier
    }
    
    // modifier for check owner
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;  // <- entry point
    }
    
    // sample function for using onlyOwner modifier
    function setC(uint256 _c) public onlyOwner {
        // require(msg.sender == owner);  // by modifier
        c = _c;
    }

    // function function_name({input_type _input_name[,]}) {visibility} {function type} {modifier[s]} {returns (return_type {_return_name}[,])} {}
    // no order for visibility, function type, modifiers
}
