// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/access/Ownable.sol";
import './interfaces/IWakaToken.sol';

contract RewardPool is Ownable {
    address public tokenStaking; //TokenStaking contract address.
    IWakaToken public WakaToken; // Rewards Token : Token for distribution as rewards.

    constructor(address _tokenStaking, address _WakaToken) {
        tokenStaking = _tokenStaking;
        WakaToken = IWakaToken(_WakaToken);
    }

    /**
     * @dev Sets `_amount` as the allowance of `tokenStaking` over the caller's tokens.
     */
    function approveWaka(uint256 _amount) external returns (bool) {
        require(tokenStaking != address(0x00));
        WakaToken.approve(tokenStaking, _amount);
        return true;
    }

    // Sets Waka token contract address.
    function setWakaTokenAddress(address _WakaToken) external onlyOwner {
        require(_WakaToken != address(0x00));
        WakaToken = IWakaToken(_WakaToken);
    }

    // Sets Token Staking contract address.
    function setTokenStakingAddress(address _tokenStaking) external onlyOwner {
        require(_tokenStaking != address(0x00));
        tokenStaking = _tokenStaking;
    }

    // Withdraws Waka tokens to _address.
    function withdrawWaka(address _address, uint256 _amount) external onlyOwner {
        require(_address != address(0x00));
        require(_amount > 0, "Withdraw: No balance to withdraw");
        WakaToken.transfer(_address, _amount);
    }
}