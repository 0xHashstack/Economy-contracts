// SPDX-License-Identifier: MIT
pragma solidity >=0.8.6 <0.9.0;

import "contracts/util/Context.sol";
import "contracts/util/Address.sol";

contract Token is Context {
    using Address for address;

    string public name;
    string public symbol;
    uint8 public decimals;

    uint256 public totalSupply;
    uint256 private cappedSupply;

    address private admin;

    bool _reentrant;
    bool _paused;

    mapping(address => uint256) _balances;
    mapping(address => mapping(address => uint256)) _allowances;

    event Transfer(
        address indexed _from,
        address indexed _to,
        uint256 indexed _value,
        uint256 _timeStamp
    );
    event Approved(
        address indexed _owner,
        address indexed _spender,
        uint256 indexed _value,
        uint256 _timeStamp
    );

    event PauseState(address indexed _pauser, bool _paused, uint256 _timeStamp);

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 initialSupply_,
        uint256 cappedSupply_,
        address admin_
    ) {
        name = name_;
        symbol = symbol_;
        decimals = decimals_;

        admin = admin_;
        _balances[admin] = initialSupply_;
        totalSupply = initialSupply_;

        cappedSupply = cappedSupply_;

        _paused = false;
        _reentrant = false;
    }

    receive() external payable {
        payable(admin).transfer(_msgValue());
    }

    fallback() external payable {
        payable(admin).transfer(_msgValue());
    }

    function pauseState() external view returns (string memory) {
        if (_paused == true) {
            return "Token transfers are disabled. Contract paused";
        }
        return "Contract is active";
    }

    function transfer(address _to, uint256 _value)
        external
        nonReentrant()
        returns (bool)
    {
        _preTransferCheck();
        require(_balances[_msgSender()] >= _value, "Insufficient balance");

        _balances[_msgSender()] -= _value;
        _balances[_to] += _value;

        emit Transfer(_msgSender(), _to, _value, block.timestamp);

        return true;
    }

    function approve(address _spender, uint256 _value) external returns (bool) {
        _preTransferCheck();
        _allowances[_msgSender()][_spender] = 0;

        require(
            _balances[_msgSender()] >= _value,
            "Insuffficient balance, or you do not have necessary permissions"
        );
        _allowances[_msgSender()][_spender] += _value;

        emit Approved(_msgSender(), _spender, _value, block.timestamp);
        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external nonReentrant() returns (bool) {
        _preTransferCheck();
        require(
            _allowances[_from][_msgSender()] >= _value &&
                _balances[_from] >= _value,
            "Insufficient allowances, or balance"
        );

        _balances[_from] -= _value;
        _balances[_to] += _value;

        _allowances[_from][_msgSender()] -= _value;

        emit Transfer(_from, _to, _value, block.timestamp);

        return true;
    }

    function mint(address _to, uint256 amount)
        external
        onlyAdmin()
        nonReentrant()
        returns (bool)
    {
        require(totalSupply <= cappedSupply, "Exceeds capped supply");
        require(amount != 0 && _to != address(0), "you can not mint 0 tokens");

        _balances[_to] += amount;
        totalSupply += amount;

        return true;
    }

    function burn(address account, uint256 amount)
        external
        onlyAdmin()
        nonReentrant()
        returns (bool)
    {
        require(
            account != address(0),
            "You can not burn tokens from this address"
        );

        _balances[account] -= amount;
        totalSupply -= amount;

        emit Transfer(account, address(0), amount, block.timestamp);

        return true;
    }

    function pause() external onlyAdmin() nonReentrant() {
        _pause();
    }

    function unpause() external onlyAdmin() nonReentrant() {
        _unpause();
    }

    function _preTransferCheck() internal view {
        require(
            _paused == false,
            "The contract is paused. Transfer functions are temporarily disabled"
        );
        this;
    }

    function _pause() internal {
        require(_paused == false, "The contract is already paused");
        _paused = true;

        emit PauseState(_msgSender(), true, block.timestamp);
    }

    function _unpause() internal {
        require(_paused == true, "The contract is already paused");
        _paused = false;

        emit PauseState(_msgSender(), false, block.timestamp);
    }

    modifier nonReentrant() {
        require(_reentrant == false, "Re-entrant");
        _reentrant = true;
        _;
        _reentrant = false;
    }

    modifier onlyAdmin() {
        require(_msgSender() == admin, "Inadequate permission");
        _;
    }
}
