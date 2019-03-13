// Copyright (C) 2017, 2018, 2019 dbrock, rain, mrchico

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

pragma solidity >=0.4.24;

contract ERC20 {
    // --- Auth ---
    mapping (address => uint256) public wards;
    function rely(address guy)   public auth { wards[guy] = 1; }
    function deny(address guy)   public auth { wards[guy] = 0; }
    modifier auth { require(wards[msg.sender] == 1); _; }

    // --- ERC20 Data ---
    uint8   constant public decimals = 18;
    string  public name;
    string  public symbol;

    mapping (address => uint)                      public balanceOf;
    mapping (address => mapping (address => uint)) public allowance;

    event Approval(address indexed src, address indexed guy, uint wad);
    event Transfer(address indexed src, address indexed dst, uint wad);
    
    // --- Cheque handling data ---
    mapping (address => uint256) public nonces;

    struct EIP712Domain {
        string  name;
        string  version;
        uint256 chainId;
        address verifyingContract;
    }
    
    struct Cheque {
        address sender;
        address receiver;
        uint256 amount;
        uint256 fee;
        uint256 nonce;
        uint256 deadline;
    }
    
    bytes32 public DOMAIN_SEPARATOR;
    bytes32 constant EIP712DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    bytes32 constant public CHEQUE_TYPEHASH = keccak256(
        "Cheque(address sender,address receiver,uint256 amount,uint256 fee,uint256 nonce,uint256 deadline)"
    );
    
    constructor(string memory symbol_, string memory name_) public {
        wards[msg.sender] = 1;
        symbol = symbol_;
        name = name_;
        balanceOf[address(0)] = uint(-1);
        DOMAIN_SEPARATOR = hash(EIP712Domain({
            name : "Dai Automated Clearing House",
                version: "1",
                chainId: 1,
                verifyingContract: address(this)}
        ));
    }

    // --- Math --- 
    function add(uint x, uint y) internal pure returns (uint z) {
        z = x + y;
        require(z >= x, "math-add-overflow");
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        z = x - y;
        require(z <= x, "math-sub-underflow");
    }

    // --- ERC20 ---
    function move(address src, address dst, uint wad) internal {
        balanceOf[src] = sub(balanceOf[src], wad);
        balanceOf[dst] = add(balanceOf[dst], wad);
        emit Transfer(src, dst, wad);
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
        if (src != msg.sender && allowance[src][msg.sender] != uint(-1)) {
            allowance[src][msg.sender] = sub(allowance[src][msg.sender], wad);
        }
        move(src, dst, wad);
        return true;
    }

    // --- Minting and burning ---
    function mint(address guy, uint wad) public auth {
        move(address(0), guy, wad);
    }
    function totalSupply() public returns (uint256) {
      return sub(uint(-1), balanceOf[address(0)]);
    }
    function burn(address guy, uint wad) public {
        transferFrom(guy, address(0), wad);
    }

    // --- Signature verification ---
    function hash(EIP712Domain memory eip712Domain) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            EIP712DOMAIN_TYPEHASH,
            keccak256(bytes(eip712Domain.name)),
            keccak256(bytes(eip712Domain.version)),
            eip712Domain.chainId,
            eip712Domain.verifyingContract
        ));
    }

    function hash(Cheque memory cheque) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CHEQUE_TYPEHASH,
            cheque.sender,
            cheque.receiver,
            cheque.amount,
            cheque.fee,
            cheque.nonce,
            cheque.deadline
        ));
    }

    function verify(Cheque memory cheque, uint8 v, bytes32 r, bytes32 s) internal view returns (bool) {
        bytes32 digest = keccak256(abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR,
                        hash(cheque)
        ));
        return ecrecover(digest, v, r, s) == cheque.sender;
    }

    // --- Transfer by cheque ---
    function clear(address _sender, address _receiver, uint _amount, uint _fee, uint _nonce, uint _deadline, uint8 v, bytes32 r, bytes32 s) public {
        Cheque memory cheque = Cheque({
            sender   : _sender,
            receiver : _receiver,
            amount   : _amount,
            fee      : _fee,
            nonce    : _nonce,
            deadline : _deadline
        });
        require(verify(cheque, v, r, s), "invalid cheque");
        require(_deadline == 0 || now <= _deadline, "cheque expired");
        require(_nonce == nonces[_sender], "invalid nonce");
        move(_sender, msg.sender, _fee);
        move(_sender, _receiver, _amount);
        nonces[_sender]++;
  }
}
