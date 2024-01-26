// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

// Openzeppelin
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract MyToken is ERC20 {
    constructor() ERC20('MyToken', 'MT') {
        _mint(msg.sender, 1000000 * (10 ** uint256(decimals())));
    }
}
