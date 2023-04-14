// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestToken is ERC20 {
    constructor(string memory _name, string memory _symbol) ERC20(_name,_symbol) {
        super._mint(_msgSender(), 3000000 ether);
    }
}