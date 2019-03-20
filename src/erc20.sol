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

    // --- Permit handling data ---
    mapping (address => uint256) public nonces;

    struct EIP712Domain {
        string  name;
        string  version;
        uint256 chainId;
        address verifyingContract;
    }

    struct Permit {
        address spender;
        uint256 nonce;
        uint256 deadline;
    }

    bytes32 public DOMAIN_SEPARATOR;
    bytes32 constant EIP712DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    bytes32 constant public permit_TYPEHASH = keccak256(
        "Permit(address spender,uint256 nonce,uint256 deadline)"
    );

    constructor(string memory symbol_, string memory name_, string memory version_, uint256 chainId_) public {
        wards[msg.sender] = 1;
        symbol = symbol_;
        name = name_;
        balanceOf[address(0)] = uint(-1);
        DOMAIN_SEPARATOR = hash(EIP712Domain({
            name : "Dai Automated Clearing House",
                version: version_,
                chainId: chainId_,
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
        move(msg.sender, dst, wad);
        return true;
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

    // --- EIP712 niceties ---
    function hash(EIP712Domain memory eip712Domain) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            EIP712DOMAIN_TYPEHASH,
            keccak256(bytes(eip712Domain.name)),
            keccak256(bytes(eip712Domain.version)),
            eip712Domain.chainId,
            eip712Domain.verifyingContract
        ));
    }

    function hash(Permit memory permit) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            permit_TYPEHASH,
            permit.spender,
            permit.nonce,
            permit.deadline
        ));
    }

    function recover(Permit memory permit, uint8 v, bytes32 r, bytes32 s) internal view returns (bool) {
        bytes32 digest = keccak256(abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR,
                        hash(permit)
        ));
        return ecrecover(digest, v, r, s);
    }

    function verify(Permit memory permit, uint8 v, bytes32 r, bytes32 s) internal view returns (bool) {
        return recover(permit, v, r, s) == permit.spender;
    }

    // --- Approval by signature ---
    function allow(address spender, uint nonce_, uint deadline_, uint8 v, bytes32 r, bytes32 s) public {
        Permit memory permit = Permit({
            spender  : spender_,
            nonce    : nonce_,
            deadline : deadline_
        });
        require(verify(permit, v, r, s), "invalid permit");
        require(deadline_ == 0 || now <= deadline_, "permit expired");
        require(nonce_ == nonces[spender_], "invalid nonce");
        nonces[spender_]++;
        allowance[holder][spender_] = uint(-1);
  }
}
