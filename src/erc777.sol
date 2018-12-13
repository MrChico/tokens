/// *** UNTESTED. DO NOT USE ***

/// Simple ERC777 implementation

// Copyright (C) 2018 Rain <rainbreak@riseup.net>
//
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

pragma solidity 0.4.24;

interface Hooks {
    function tokensToSend(address operator, address from, address to, uint amount, bytes data, bytes operatorData) external;
    function tokensReceived(address operator, address from, address to, uint amount, bytes data, bytes operatorData) external;
}

interface EIP820 {
    function getInterfaceImplementer(address addr, bytes32 iHash) external view returns (address);
    function setInterfaceImplementer(address addr, bytes32 iHash, address implementer) external;
}

contract ERC777 {
    string  public name;
    string  public symbol;
    uint8   public decimals = 18;
    uint256 public granularity = 1;
    uint256 public totalSupply;

    EIP820  public interfaceRegistry = EIP820(address(0x820));  // TODO: actual address

    mapping (address => mapping (address => bool)) authorized;
    mapping(address => uint) public balanceOf;
    address[] public defaultOperators;

    event Sent(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes   data,
        bytes   operatorData
    );
    event Minted(address indexed operator, address indexed to, uint256 amount, bytes data, bytes operatorData);
    event Burned(address indexed operator, address indexed from, uint256 amount, bytes operatorData);
    event AuthorizedOperator(address indexed operator, address indexed tokenHolder);
    event RevokedOperator(address indexed operator, address indexed tokenHolder);

    constructor(string symbol_, string name_) public {
        symbol = symbol_;
        name = name_;
        interfaceRegistry.setInterfaceImplementer(this, keccak256("ERC777Token"), this);
    }

    function isOperatorFor(address operator, address tokenHolder) public view returns (bool) {
        return operator == tokenHolder || authorized[operator][tokenHolder];
    }
    function authorizeOperator(address operator) public {
        require(operator != msg.sender);
        authorized[operator][msg.sender] = true;
        emit AuthorizedOperator(operator, msg.sender);
    }
    function revokeOperator(address operator) public {
        require(operator != msg.sender);
        authorized[operator][msg.sender] = false;
        emit RevokedOperator(operator, msg.sender);
    }

    function sendHook(address from, address to, uint amount, bytes data, bytes operatorData) internal returns (address) {
        address impl = interfaceRegistry.getInterfaceImplementer(from, keccak256("ERC777TokensSender"));
        if (impl != address(0)) {
            Hooks(impl).tokensReceived(msg.sender, from, to, amount, data, operatorData);
        }
    }
    function recvHook(address from, address to, uint amount, bytes data, bytes operatorData) internal returns (address) {
        address impl = interfaceRegistry.getInterfaceImplementer(to, keccak256("ERC777TokensRecipient"));
        if (impl != address(0)) {
            Hooks(impl).tokensReceived(msg.sender, from, to, amount, data, operatorData);
        }
    }

    modifier auth { _; } // TODO: auth
    function mint(address to, uint amount) public auth {
        require(to != address(0));

        balanceOf[to] += amount;
        totalSupply   += amount;
        recvHook(0x00, to, amount, "", "");

        emit Minted(msg.sender, to, amount, "", "");
    }
    function operatorBurn(address from, uint256 amount, bytes data, bytes operatorData) public {
        require(isOperatorFor(from, msg.sender));
        require(from != address(0));
        require(balanceOf[from] >= amount);

        sendHook(from, 0x00, amount, data, operatorData);
        balanceOf[from] -= amount;
        totalSupply     -= amount;

        emit Burned(msg.sender, from, amount, operatorData);
    }
    function operatorSend(address from, address to, uint amount, bytes data, bytes operatorData) public {
        require(isOperatorFor(from, msg.sender));
        require(to != address(0));
        require(balanceOf[from] >= amount);

        sendHook(from, to, amount, data, operatorData);
        balanceOf[from] -= amount;
        balanceOf[to]   += amount;
        recvHook(from, to, amount, data, operatorData);

        emit Sent(msg.sender, from, to, amount, data, operatorData);
    }

    function burn(uint256 amount, bytes data) public {
        operatorBurn(msg.sender, amount, data, "");
    }
    function burn(address guy, uint wad) public {
        operatorBurn(guy, wad, "", "");
    }
    function send(address to, uint amount, bytes data) public {
        operatorSend(msg.sender, to, amount, data, "");
    }
}
