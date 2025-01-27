// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

import "hardhat/console.sol";

contract YesuVault is Ownable {

  using SafeERC20 for IERC20;

  address public manager = msg.sender;

  IERC20 public fundsToken;

  uint public last_completed_migration;

  mapping(uint256 => bool) public depositOrder;

  event Deposit(uint256 indexed orderId, address indexed user, uint256 amount);

  constructor(address _manager, address _fundsToken)  Ownable(msg.sender) {

    manager = _manager;
    fundsToken = IERC20(_fundsToken);
  }


  function deposit(uint256 orderId,uint256 amount,address user,uint256 deadline, bytes memory signature) public {

    checkSign(orderId, amount, user, deadline, signature);

    require(!depositOrder[orderId], "Order exist");

    fundsToken.safeTransferFrom(msg.sender, address(this), amount);

    depositOrder[orderId] = true;

    emit Deposit(orderId, msg.sender, amount);
  }

  function checkSign(
      uint256 orderId,uint256 amount,address user,uint256 deadline,
      bytes memory signature
  ) public view {

    require(block.timestamp >= deadline, "Out of dead");

    bytes32 r;
    bytes32 s;
    uint8 v;
    assembly {
        r := mload(add(signature, 0x20))
        s := mload(add(signature, 0x40))
        v := byte(0, mload(add(signature, 0x60)))
    }

    bytes32 digest = keccak256(
        abi.encodePacked(
            "\x19Ethereum Signed Message:\n32",
            keccak256(
            abi.encode(
              orderId,
                    amount,
                    user,
                    deadline
            ))
        )
    );

    address recoveredAddress = ecrecover(digest, v, r, s);
    require(recoveredAddress != address(0) && recoveredAddress == manager, 'Space: INVALID_SIGNATURE');
  }

  function setManager(address _manager) public onlyOwner() {
    manager = _manager;
  }

    function setFundsToken(address _fundsToken) public onlyOwner() {
    fundsToken = IERC20(_fundsToken);
  }

  function withdrawAssets(address token, address to, uint256 amount) public onlyOwner() {

    if(address(0) == token) {
      payable(to).transfer(amount);
    } else {
      IERC20(token).transfer(to, amount);
    }
  }
}
