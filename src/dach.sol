pragma solidity ^0.4.23;
import "ds-math/math.sol";

contract GemLike {
    function transfer(address,uint) public returns (bool);
    function transferFrom(address,address,uint) public returns (bool);
    function mint(address,uint) public;
    function burn(address,uint) public;
}

contract Dach {
  mapping (address => uint256) public nonces;
  bytes32 public DOMAIN_SEPARATOR;

  bytes32 constant EIP712DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
  );

  bytes32 constant public CHEQUE_TYPEHASH = keccak256(
       "Cheque(address token,address sender,address receiver,uint256 amount,uint256 fee,uint256 nonce)"
  );


  struct EIP712Domain {
    string  name;
    string  version;
    uint256 chainId;
    address verifyingContract;
  }

  struct Cheque {
    address token;
    address sender;
    address receiver;
    uint256 amount;
    uint256 fee;
    uint256 nonce;
  }

  constructor() {
    mover = new Mover();
    DOMAIN_SEPARATOR = hash(EIP712Domain({
            name : "Dai Automated Clearing House",
            version: "1",
            chainId: 1,
            verifyingContract: 0xdeadbeef} //TODO: set to "this"
            //            verifyingContract: this}
        ));
  }

  function hash(EIP712Domain eip712Domain) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            EIP712DOMAIN_TYPEHASH,
            keccak256(bytes(eip712Domain.name)),
            keccak256(bytes(eip712Domain.version)),
            eip712Domain.chainId,
            eip712Domain.verifyingContract
        ));
  }

  function hash(Cheque cheque) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            CHEQUE_TYPEHASH,
            cheque.token,
            cheque.sender,
            cheque.receiver,
            cheque.amount,
            cheque.fee,
            cheque.nonce
        ));
    }


  function verify(Cheque cheque, uint8 v, bytes32 r, bytes32 s) internal returns (bool) {
    bytes32 digest = keccak256(abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR,
                        hash(cheque)
                     ));
    return ecrecover(digest, v, r, s) == cheque.sender;
  }

  
  function clear(address _token, address _sender, address _receiver, uint _amount, uint _fee, uint _nonce, uint8 v, bytes32 r, bytes32 s) public {
    Cheque memory cheque = Cheque({
      token    : _token,
      sender   : _sender,
      receiver : _receiver,
      amount   : _amount,
      fee      : _fee,
      nonce    : _nonce
    });
    require(verify(cheque, v, r, s));
    require(cheque.nonce == nonces[cheque.sender]);
    GemLike memory _token;
    require(GemLike.transferFrom(cheque.sender, msg.sender, cheque.fee));
    require(GemLike.transferFrom(cheque.sender, cheque.receiver, cheque.amount));
    nonces[cheque.sender]++;
  }
}
