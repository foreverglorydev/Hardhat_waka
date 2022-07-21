// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWakaToken is IERC20 {
    function decimals() external view returns (uint8);
    function mint(address, uint256) external returns (bool);
    function burn(uint256) external returns (bool);
    function airdrop(address) external;
}
