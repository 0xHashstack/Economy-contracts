// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import ".././util/Address.sol";
import ".././util/Context.sol";
import ".././util/IERC20.sol";

contract Stack is Context{
  using Address for address;
  
  string public name;
  string public symbol;
  uint8 public decimals;

  uint256 public totalSupply;
  uint256 public cappedSupply;

  mapping(address => uint256) private _balances;
  mapping(address => mapping(address => uint256)) private _allowances;
  mapping(address => bool) private _blacklist;

  address private admin;

  bool public isLocked;
  bool public isReentrant;

  event Transfer( address indexed from, address indexed to, uint256 indexed value);
  event Approval( address indexed owner, address indexed  spender, uint256 indexed amount);

  event ContractState(bool isLocked, address from);
  event LockUser(address user);
  event UnlockUser(address user);
  
   constructor(string memory name_, string memory symbol_, uint8 decimals_, address admin_, uint256 initialSupply_, uint256 cappedSupply_) {
    name = name_;
    symbol = symbol_;
    decimals = decimals_;

    isLocked = false;
    isReentrant = false;

    admin = admin_;
    cappedSupply = cappedSupply_;
    // _balances[admin] = _balances[admin] + initialSupply_;

    // totalSupply = totalSupply + initialSupply_;

    // emit Transfer(address(0), admin, initialSupply_);

    _mint(admin, initialSupply_);
    emit Transfer(address(0), admin, initialSupply_);

  }

/// RECEIVE ETHER
  receive() external payable {
    payable(admin).transfer(_msgValue());
  }

  fallback() external payable {
    payable(admin).transfer(_msgValue());
  }


/// TRANSFER ACCIDENTAL TOKEN TRANSFERS BACK TO THE OWNERS. 
  function transferAnyErc20Token(address _token, address payable _to, uint256 _amount) external validLock reentrancyGuard auth returns(bool)   {
    IERC20(_token).transfer(_to, _amount);

    return true;
  }


/// EXTERNAL VIEW FUNCTIONS
  function balanceOf(address addr) external view  returns(uint256)  {
    return _balances[addr];
  }

  function allowances(address owner, address  _spender) external view returns(uint256)  {
    return _allowances[owner][_spender];
  }

  function contractState() external view returns(bool)  {
    return isLocked;
  }


  function checkRestriction(address _user) external view returns(bool)  {
    return _blacklist[_user];
  }


/// RESTRICT BAD PLAYERS WITHOUT LOCKING THE CONTRACT 
  function restrictAddress(address _user) external validLock auth returns(bool) {
    
    require(_blacklist[_user] != true, "This address is already restricted.");
    _blacklist[_user] = true;
    
    emit LockUser(_user);
    return true;
  }

  function removeRestriction(address _user) external validLock auth returns(bool){
    
    require(_blacklist[_user] == true, "This address is not restricted");
    _blacklist[_user] = false;
    
    emit UnlockUser(_user);
    return true;
  }


/// TOKEN TRANSFER FUNCTIONS 
  function transfer(address _to, uint256 _amount) external validLock reentrancyGuard returns(bool) {

    _preTradeCheck(_msgSender(), _to, _amount);
    _transfer(_msgSender(), _to, _amount);

    return true;
  }

  // batchTransfer is to enable bulk token distribution from msg.sender.
  function batchTransfer(address[] calldata _recipient, uint256[] calldata _amount) external validLock reentrancyGuard  returns(bool) {
    require(_recipient.length == _amount.length, "mismatch entries");

    uint256 size = _recipient.length;

    for (uint256 i = 0; i<size; i++) {
      _preTradeCheck(_msgSender(), _recipient[i], _amount[i]);
      _transfer(_msgSender(), _recipient[i], _amount[i]);
    }
     return true;
  }

  function approve(address _spender, uint256 _amount) external validLock reentrancyGuard returns(bool) {

    _preTradeCheck(_msgSender(), _spender, _amount);

    _allowances[_msgSender()][_spender] = 0;
    _approve(_msgSender(), _spender, _amount);

    return true;

  }
  
  function transferFrom(address _owner, address _recipient, uint256 _amount) external reentrancyGuard returns(bool) {

    _preTradeCheck(_owner, _msgSender(), _amount);
    require(_recipient != address(0) && _blacklist[_recipient] != true, "You cannot transfer funds to a restricted address");

    _decreaseAllowance(_owner, _msgSender(), _amount);
    _transfer(_owner, _recipient, _amount);

    return true;
  }
  
  function increaseAllowance(address _spender, uint256 _amount) external validLock reentrancyGuard returns (bool) {
    
    _preTradeCheck(_msgSender(), _spender, _amount);
    _increaseAllowance(_msgSender(), _spender, _amount);

    return true;
  }

  function decreaseAllowance(address  _spender, uint256 _amount) external validLock reentrancyGuard returns (bool) {
    
    _preTradeCheck(_msgSender(), _spender, _amount);  
    _decreaseAllowance(_msgSender(), _spender, _amount);

    return true;
  }
  
  function mint(address _to, uint256 _amount) external validLock reentrancyGuard auth returns(bool) {
    
    require(totalSupply + _amount <= cappedSupply, "You can not mint more than permissible amount of tokens");
    _mint(_to, _amount);

    return true;
  }

  function burn(address _from, uint256 _amount) external validLock returns(bool){

    require(_balances[_from] >= _amount, "Insufficient balance");
    _burn(_from, _amount);

    return true;
  }

  function lockContract() external validLock reentrancyGuard auth returns(bool)  {
    _lock(_msgSender());

    return true;
  }

  function unlockContract() external validLock reentrancyGuard auth returns(bool)  {
    _unlock(_msgSender());

    return true;
  }


/// PRIVATE FUNCTIONS 

  function _preTradeCheck(address _from, address _to, uint256 _amount) private view  {
    require(_from != address(0) && _to != address(0), "Zero address can not be used in a transaction");
    require(_blacklist[_from] != true && _blacklist[_to] != true, "Blacklisted address can not be used in a transaction");
    require(_balances[_from] >= _amount, "Insufficient balance");
  }

  function _transfer(address _from, address _to, uint256 _amount) private {

    _balances[_from] = _balances[_from] - _amount;
    _balances[_to] = _balances[_to] + _amount;

    emit Transfer(_from, _to, _amount);
  }

  function _approve(address _owner, address _spender, uint256 _value) private {

    _allowances[_owner][_spender] = _value;

    emit Approval(_owner, _spender, _value);

  }

  function _increaseAllowance(address _owner, address _spender, uint256 _amount) private reentrancyGuard  returns(bool) {
    
    require(_allowances[_owner][_spender] > 0, "Your existing allowances are zero. Please use approve() for allowances");
    uint256 _value = _allowances[_owner][_spender] + _amount;

    _approve(_owner,  _spender, _value);

    return true;
  }


  function _decreaseAllowance(address _owner, address _spender, uint256 _amount) private{
    
    require(_allowances[_owner][_spender] > 0 && _amount >=0 , "Allowance can not be negative.");
    uint256 _value = _allowances[_owner][_spender] - _amount;

    _approve(_owner,  _spender, _value);

  }

  function _mint(address _to, uint256 _amount) private  {

    _balances[_to] = _balances[_to] + _amount;
    totalSupply = totalSupply + _amount;

    emit Transfer(address(0), _to, _amount);
  }

  function _burn(address _from, uint256 _amount) private {
    
    _balances[_from] = _balances[_from] - _amount;
    totalSupply = totalSupply - _amount;

    emit Transfer(_from, address(0), _amount);
  }

  function _lock(address _from) private {
    isLocked = true;

    emit ContractState(isLocked, _from);

  }

  function _unlock(address _from) private  {
    isLocked = false;

    emit ContractState(isLocked, _from);
  }

/// MODIFIERS

  modifier validLock  {
    require(isLocked == false, "This contract is locked. Transactions are temporarily disabled");
    _;
  }

  modifier auth {
    require(_msgSender() == admin, "You don't have adequate permissions");
    _;
  }

  modifier reentrancyGuard  {
    require(isReentrant == false, "Re-entrancy denied");
    isReentrant = true;
    _;
    isReentrant = false;
  }

}