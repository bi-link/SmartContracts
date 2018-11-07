//reference:https://github.com/OpenZeppelin/zeppelin-solidity/tree/master/contracts
contract Ownable 
{
  address public owner;
 
  constructor(address _owner) public 
  {
    owner = _owner;
  }
 
  modifier onlyOwner() 
  {
    require(msg.sender == owner);
    _;
  }
 
  function transferOwnership(address newOwner) onlyOwner 
  {
    require(newOwner != address(0));      
    owner = newOwner;
  }
}
