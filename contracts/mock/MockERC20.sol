// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {


  constructor(string memory name, string memory symbol)  ERC20(name, symbol) {


    _mint(msg.sender, 1000000000000000 ether);
  }

  function mint(address account, uint256 amount) public {
    _mint(account, amount);
  }


}
