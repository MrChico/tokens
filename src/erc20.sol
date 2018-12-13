// Copyright (C) 2017, 2018 dbrock, rain

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity ^0.4.24;

contract ERC20 {
    string  public name;
    string  public symbol;
    uint8   public decimals = 18;
    uint256 public totalSupply;

    mapping (address => uint)                       public  balanceOf;
    mapping (address => mapping (address => uint))  public  allowance;

    address[] public defaultOperators;
    mapping(address => bool) public isDefaultOperator;
    
    event Approval(address indexed src, address indexed guy, uint wad);
    event Transfer(address indexed src, address indexed dst, uint wad);

    constructor(string symbol_, string name_, address[] defaultOperators_) public {
        symbol = symbol_;
        name = name_;
        defaultOperators = defaultOperators_;
        for (var i; i < defaultOperators_.length; i++) {
          isDefaultOperator[defaultOperators_[i]] = true;
        }
    }

    function approve(address guy, uint wad) public returns (bool) {
        allowance[msg.sender][guy] = wad;
        emit Approval(msg.sender, guy, wad);
        return true;
    }
    function transfer(address dst, uint wad) public returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }
    function transferFrom(address src, address dst, uint wad)
        public returns (bool)
    {
        require(balanceOf[src] >= wad);
        if (src != msg.sender
            && allowance[src][msg.sender] != uint(-1)
            && !isDefaultOperator[msg.sender]) {
            require(allowance[src][msg.sender] >= wad);
            allowance[src][msg.sender] -= wad;
        }
        balanceOf[src] -= wad;
        balanceOf[dst] += wad;
        emit Transfer(src, dst, wad);
        return true;
    }

    modifier auth { _; }  // TODO: auth
    function mint(address guy, uint wad) public auth {
        balanceOf[guy] += wad;
        totalSupply    += wad;
        emit Transfer(address(0), guy, wad);
    }
    function burn(address guy, uint wad) public {
        require(balanceOf[guy] >= wad);
        if (guy != msg.sender && allowance[guy][msg.sender] != uint(-1)) {
            require(allowance[guy][msg.sender] >= wad);
            allowance[guy][msg.sender] -= wad;
        }
        balanceOf[guy] -= wad;
        totalSupply    -= wad;
        emit Transfer(guy, address(0), wad);
    }
}
