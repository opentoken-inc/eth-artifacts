pragma solidity ^0.4.21;

library SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    require(c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    return a / b;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a);
    return c;
  }
}

interface Token {
  event Transfer(address indexed _from, address indexed _to, uint256 _value);
  event Approval(address indexed _owner, address indexed _spender, uint256 _value);

  function transfer(address _to, uint256 _value) external returns (bool success);

  function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);

  function balanceOf(address _owner) external view returns (uint256 balance);

  function approve(address _spender, uint256 _value) external returns (bool success);

  function allowance(address _owner, address _spender) external view returns (uint256 remaining);
}

contract TokenImpl is Token {
  using SafeMath for uint256;
  uint256 constant MAX_UINT256 = 2**256 - 1;

  mapping (address => uint256) balances;
  mapping (address => mapping (address => uint256)) allowed;

  constructor() public {
    balances[msg.sender] = 10000000000000000;
  }

  function transfer(address _to, uint256 _value) public returns (bool success) {
      balances[msg.sender] = balances[msg.sender].sub(_value);
      balances[_to] = balances[_to].add(_value);
      emit Transfer(msg.sender, _to, _value);
      return true;
  }

  function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
      uint256 allowance = allowed[_from][msg.sender];
      if (allowance < MAX_UINT256) {
          allowed[_from][msg.sender] = allowance.sub(_value);
      }

      balances[msg.sender] = balances[msg.sender].sub(_value);
      balances[_to] = balances[_to].add(_value);
      emit Transfer(msg.sender, _to, _value);
      return true;
  }

  function balanceOf(address _owner) public view returns (uint256 balance) {
      return balances[_owner];
  }

  function approve(address _spender, uint256 _value) public returns (bool success) {
      allowed[msg.sender][_spender] = _value;
      emit Approval(msg.sender, _spender, _value);
      return true;
  }

  function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
    return allowed[_owner][_spender];
  }
}


library ECTools {

  // @dev Recovers the address which has signed a message
  // @thanks https://gist.github.com/axic/5b33912c6f61ae6fd96d6c4a47afde6d
  function recoverSigner(bytes32 _hashedMsg, bytes _sig) public pure returns (address) {
    require(_hashedMsg != 0x00);

    if (_sig.length != 65) {
      return 0x0;
    }
    bytes32 r;
    bytes32 s;
    uint8 v;
    assembly {
      r := mload(add(_sig, 32))
      s := mload(add(_sig, 64))
      v := byte(0, mload(add(_sig, 96)))
    }
    if (v < 27) {
      v += 27;
    }
    if (v < 27 || v > 28) {
      return 0x0;
    }
    return ecrecover(_hashedMsg, v, r, s);
  }

  // @dev Verifies if the message is signed by an address
  function isSignedBy(bytes32 _hashedMsg, bytes _sig, address _addr) public pure returns (bool) {
    require(_addr != 0x0);

    return _addr == recoverSigner(_hashedMsg, _sig);
  }

  function toEthereumSignedMessage(string _msg) public pure returns (bytes32) {
    uint len = bytes(_msg).length;
    require(len > 0);
    bytes memory prefix = "\x19Ethereum Signed Message:\n";
    return keccak256(prefix, uintToString(len), _msg);
  }

  // @dev Converts a uint in a string
  function uintToString(uint _uint) public pure returns (string str) {
    uint len = 0;
    uint m = _uint + 0;
    while (m != 0) {
      len++;
      m /= 10;
    }
    bytes memory b = new bytes(len);
    uint i = len - 1;
    while (_uint != 0) {
      uint remainder = _uint % 10;
      _uint = _uint / 10;
      b[i--] = byte(48 + remainder);
    }
    str = string(b);
  }

  //function join(string _delimiter, string _a, string _b, string _c) external pure returns (string str) {
    //bytes memory _bd = bytes(_delimiter);
    //bytes memory _ba = bytes(_a);
    //bytes memory _bb = bytes(_b);
    //bytes memory _bc = bytes(_c);
    //string memory adbdcd = new string(_ba.length + _bd.length + _bb.length + _bd.length + _bc.length);
    //bytes memory badbdcd = bytes(adbdcd);
    //uint k = 0;
    //for (uint i = 0; i < _ba.length; i++) badbdcd[k++] = _ba[i];
    //for (i = 0; i < _bd.length; i++) badbdcd[k++] = _bd[i];
    //for (i = 0; i < _bb.length; i++) badbdcd[k++] = _bb[i];
    //for (i = 0; i < _bd.length; i++) badbdcd[k++] = _bd[i];
    //for (i = 0; i < _bc.length; i++) badbdcd[k++] = _bc[i];
    //return string(badbdcd);
  //}
}


// Requires 3 operations to start.
// 1. Deploy contract
// 2. Send tokens
// 3. Call open()
contract ERC20Channel {
  using SafeMath for uint256;

  Token public token;
  address public assistant;
  address public payer;
  address public receiver;
  uint256 recoveryTimeout;

  uint256 public earliestRecoveryTime;
  bool public hasOpened;

  // Amount of token in the channel.
  uint256 public amount;

  constructor(Token _token, address _assistant, address _payer, address _receiver,
              uint256 _amount, uint256 _recoveryTimeout) public {
    token = _token;
    assistant = _assistant;
    payer = _payer;
    receiver = _receiver;
    amount = _amount;
    recoveryTimeout = _recoveryTimeout;
  }

  function open() public {
    uint256 thisBalance = token.balanceOf(address(this));
    require(thisBalance >= amount);
    earliestRecoveryTime = now.add(recoveryTimeout);
    amount = thisBalance;
    hasOpened = true;
  }

  function recover() public {
    require(!hasOpened || now >= earliestRecoveryTime);
    require(msg.sender == assistant || msg.sender == payer);

    token.transfer(payer, token.balanceOf(address(this)));
  }

  function close(bytes payerSignature, uint256 paymentAmount) public {
    require(msg.sender == assistant || msg.sender == receiver);

    require(isValidPayment(payerSignature, paymentAmount));
    require(token.transfer(payer, paymentAmount));
    require(token.transfer(receiver, amount.sub(paymentAmount)));
  }

  function isValidPayment(bytes payerSignature, uint256 paymentAmount)
      public view returns (bool) {
    uint256 paymentId = getPaymentIdToSign(paymentAmount);
    bytes32 msgHash = ECTools.toEthereumSignedMessage(ECTools.uintToString(paymentId));
    return ECTools.isSignedBy(msgHash, payerSignature, payer);
  }

  // Gets a 32 byte payment id.
  // This big integer (~77 digit) should be signed to send the payment.
  function getPaymentIdToSign(uint256 paymentAmount)
      public view returns (uint256) {
    require(hasOpened);
    require(paymentAmount <= amount);

    return uint256(keccak256(address(this), 'close', paymentAmount));
  }

  function recoverOtherToken(Token _token, uint256 _value) public {
    require(msg.sender == assistant);
    require(address(_token) != address(token));
    _token.transfer(assistant, _value);
  }
}

contract ERC20ChannelCreator {
  address public backupOwner;
  address public owner;
  uint256 public minFee = 0 ether;

  constructor() public {
    owner = msg.sender;
    backupOwner = msg.sender;
  }

  function createChannel(Token _token, address _receiver, uint256 _amount)
      public payable returns (address) {
    require(msg.value >= minFee);
    return _create(_token, msg.sender, _receiver, _amount, 60 days);
  }

  function createChannelWithOptions(Token _token, address _payer, address _receiver,
                                    uint256 _amount, uint256 _recoveryTimeout)
      public payable returns (address) {
    require(msg.value >= minFee);
    return _create(_token, _payer, _receiver, _amount, _recoveryTimeout);
  }

  function _create(Token _token, address _payer, address _receiver,
                   uint256 _amount, uint256 _recoveryTimeout)
      internal returns (address) {
    ERC20Channel channel = new ERC20Channel(_token, owner, _payer,
                                            _receiver, _amount, _recoveryTimeout);
    return address(channel);
  }

  function setBackupOwner(address _backupOwner) public {
    require(msg.sender == owner);
    backupOwner = _backupOwner;
  }

  function recoverOwner(address _newBackupOwner) public {
    require(msg.sender == backupOwner);
    owner = _newBackupOwner;
  }

  function createChannelByOwner(Token _token, address _payer, address _receiver,
                                uint256 _amount, uint256 _recoveryTimeout)
      public returns (address) {
    require(msg.sender == owner);
    return _create(_token, _payer, _receiver, _amount, _recoveryTimeout);
  }

  function setMinFee(uint256 newMinFeeWei) public {
    require(msg.sender == owner);
    minFee = newMinFeeWei;
  }

  function withdrawFees(Token _token, uint256 _value) public {
    require(msg.sender == owner);
    if (address(_token) == 0) {
      address(this).transfer(_value);
    }
    _token.transfer(owner, _value);
  }
}
