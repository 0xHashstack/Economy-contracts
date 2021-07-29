// SPDX-License-Identifier: MIT
pragma solidity >=0.8.6 <0.9.0;

import ".././util/Address.sol";
import ".././util/Context.sol";
import ".././util/IERC20.sol";

contract Stack is Context, IERC20 {
    using Address for address;

    string public name;
    string public symbol;
    uint8 public decimals;

    uint256 _totalSupply;
    uint256 cappedSupply;

    address admin;

    bool _reentrant = false;
    bool _paused = false;

    mapping(address => uint256) _balances;
    mapping(address => mapping(address => uint256)) _allowances;

    event Transfer(
        address indexed _from, 
        address indexed _to, 
        uint256 _value
    );

    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _value
    );
    event PauseState(
        address indexed _pauser, 
        bool _paused
    );

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address admin_,
        uint256 cappedSupply_
    ) {
        name = name_;
        symbol = symbol_;
        decimals = decimals_;

        admin = admin_;
        cappedSupply = cappedSupply_;

        _mint(admin, 1000);
    }

    receive() external payable {
        payable(admin).transfer(_msgValue());
    }

    fallback() external payable {
        payable(admin).transfer(_msgValue());
    }

    function transferAnyERC20(address token_,address recipient_,uint256 amount_) external auth() nonReentrant() {
        IERC20(token_).transfer(recipient_, amount_);
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function allowance(address _owner, address _spender) public view override returns (uint256 remaining)    {
        return _allowances[_owner][_spender];
    }

    function pauseState() external view returns (string memory) {
        if (_paused == true) {
            return "Contract is paused. Token transfers are temporarily disabled.";
        }
        return "Contract is not paused";
    }

    function pause() public auth() nonReentrant() {
        _pause();
    }

    function unpause() public auth() nonReentrant() {
        _unpause();
    }

    function transfer(address _to, uint256 _value) public override nonReentrant() returns (bool success) {
        _checkPauseState();
        _transfer(_msgSender(), _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public override returns (bool) {
        _checkPauseState();
        _approve(_spender, _value);
        return true;
    }

    function transferFrom(address _from,address _to,uint256 _value) public override nonReentrant() returns (bool) {
        _checkPauseState();
        require (_allowances[_from][_msgSender()] >= _value && _balances[_from] >= _value, "Insufficient balance, or allowance");
        _transfer(_from, _to, _value);
        
        _allowances[_from][_msgSender()] -= _value;
        return true;
    }

    // This works too
    function _mint(address _to, uint256 amount) internal auth() nonReentrant() {
        _checkPauseState();
        require(_totalSupply <= cappedSupply && amount != 0 && _to != address(0),"Token mint is not permitted");
        _balances[_to] += amount;
        _totalSupply += amount;

        emit Transfer(address(0), _to, amount);
    }

    function _burn(address account, uint256 amount) internal auth() nonReentrant()    {
        _checkPauseState();
        require(account != address(0),"You can not burn tokens from this account");

        _balances[account] -= amount;
        _totalSupply -= amount;
        emit Transfer(account, address(0), amount);
    }

    function _checkPauseState() internal view {
        require(_paused == false,"The contract is paused. Transfer functions are temporarily disabled");
    }

    function _pause() private {
        require(_paused == false, "This contract is already paused");
        _paused = true;

        emit PauseState(_msgSender(), true);
    }

    function _unpause() private {
        require(_paused == true, "This contract is already paused");
        _paused = false;

        emit PauseState(_msgSender(), false);
    }

    function _transfer(address sender, address recipient, uint256 amount) private {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(_balances[sender] >= amount, "You do not have enough balance");

        _balances[sender] -= amount;
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);

    }

    function _approve(address _spender, uint256 _value) private {
        require(_balances[_msgSender()] >= _value, "Insufficient balance");
        require(_msgSender() != address(0), "ERC20: approve from the zero address");
        require(_spender != address(0), "ERC20: approve to the zero address");

        _allowances[_msgSender()][_spender] = _value;

        emit Approval(_msgSender(), _spender, _value);
        
    }

    modifier nonReentrant() {
        require(_reentrant == false, "Re-entrant alert!");
        _reentrant = true;
        _;
        _reentrant = false;
    }

    modifier auth() {
        require(_msgSender() == admin, "Inadequate permission");
        _;
    }
}
