// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./WakaToken.sol";


// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once Waka is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract TokenStaking is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;         // How many LP tokens the user has provided.
        uint256 rewardDebt;     // Reward debt. See explanation below.
        uint256 rewardLockedUp;  // Reward locked up.
        uint256 stakedTime;     // Staked timestamp.
        //
        // We do some fancy math here. Basically, any point in time, the amount of Wakas
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accWakaPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accWakaPerShare` (and `lastRewardStamp`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 lastRewardStamp;  // Last block timestamp that Wakas distribution occurs.
        uint256 accWakaPerShare;   // Accumulated Wakas per share, times 1e12. See below.
        uint256 totalDeposits;    // Total tokens deposited in the pool.
        uint256 totalRewarded;     // Total tokens rewarded in the pool.
    }

    // The Waka TOKEN!
    WakaToken public waka;
    // Bonus muliplier for early waka makers.
    uint256 public constant BONUS_MULTIPLIER = 1;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;


    // The block timestamp when Waka mining starts.
    uint256 public startStamp;
    // Total locked up rewards
    uint256 public totalLockedUpRewards;
    // Reward Pool contract address
    address public rewardContract;
    // Unstaking fee period (default period = 3 hours)
    uint256 public unstakingFeePeriod = 10800;


    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmissionRateUpdated(address indexed caller, uint256 previousAmount, uint256 newAmount);
    event RewardLockedUp(address indexed user, uint256 indexed pid, uint256 amountLockedUp);

    constructor(
        WakaToken _waka,
        uint256 _startStamp
    ) {
        waka = _waka;
        startStamp = _startStamp;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(IERC20 _lpToken, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardStamp = block.timestamp > startStamp ? block.timestamp : startStamp;
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            lastRewardStamp: lastRewardStamp,
            accWakaPerShare: 0,
            totalDeposits: 0,
            totalRewarded: 0
        }));
    }

    // Return reward multiplier over the given _from to _to timestamp.
    function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // View function to see pending Wakas on frontend.
    function pendingWaka(uint256 _pid, address _user) external view returns (uint256) {
        require(rewardContract != address(0x00));

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        uint256 accWakaPerShare = pool.accWakaPerShare;
        uint256 lpSupply = pool.totalDeposits;
        if (block.timestamp > pool.lastRewardStamp && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardStamp, block.timestamp);

            uint256 rewardPoolBal = waka.balanceOf(rewardContract);
            uint256 wakaPerSecond = rewardPoolBal.div(365).div(24).div(3600);
            uint256 wakaReward = multiplier.mul(wakaPerSecond);

            accWakaPerShare = accWakaPerShare.add(wakaReward.mul(1e12).div(lpSupply));
        }
        uint256 pending = user.amount.mul(accWakaPerShare).div(1e12).sub(user.rewardDebt);
        return pending.add(user.rewardLockedUp);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        require(rewardContract != address(0x00));

        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardStamp) {
            return;
        }

        uint256 lpSupply = pool.totalDeposits;
        if (lpSupply == 0) {
            pool.lastRewardStamp = block.timestamp;
            return;
        }

        uint256 multiplier = getMultiplier(pool.lastRewardStamp, block.timestamp);

        uint256 rewardPoolBal = waka.balanceOf(rewardContract);
        uint256 wakaPerSecond = rewardPoolBal.div(365).div(24).div(3600);
        uint256 wakaReward = multiplier.mul(wakaPerSecond);

        pool.accWakaPerShare = pool.accWakaPerShare.add(wakaReward.mul(1e12).div(lpSupply));
        pool.lastRewardStamp = block.timestamp;
    }

    // Deposit LP tokens to TokenStaking for Waka allocation.
    function deposit(uint256 _pid, uint256 _amount) public nonReentrant {
        require(rewardContract != address(0x00));

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);

        uint256 pending = user.amount.mul(pool.accWakaPerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0 || user.rewardLockedUp > 0) {
            uint256 totalRewards = pending.add(user.rewardLockedUp);

            // reset lockup
            totalLockedUpRewards = totalLockedUpRewards.sub(user.rewardLockedUp);
            user.rewardLockedUp = 0;

            // send rewards
            safeWakaTransferFrom(rewardContract, msg.sender, totalRewards);
            pool.totalRewarded = pool.totalRewarded.add(totalRewards);
        }

        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
            pool.totalDeposits = pool.totalDeposits.add(_amount);

            user.stakedTime = block.timestamp;
        }
        user.rewardDebt = user.amount.mul(pool.accWakaPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from TokenStaking.
    function withdraw(uint256 _pid, uint256 _amount) public nonReentrant {
        require(rewardContract != address(0x00));

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);

        uint256 pending = user.amount.mul(pool.accWakaPerShare).div(1e12).sub(user.rewardDebt);
        if (_amount > 0) {
            if (pending > 0 || user.rewardLockedUp > 0) {
                uint256 totalRewards = pending.add(user.rewardLockedUp);

                // reset lockup
                totalLockedUpRewards = totalLockedUpRewards.sub(user.rewardLockedUp);
                user.rewardLockedUp = 0;

                // send rewards
                safeWakaTransferFrom(rewardContract, msg.sender, totalRewards);
                pool.totalRewarded = pool.totalRewarded.add(totalRewards);
            }
            
            if (block.timestamp.sub(user.stakedTime) < unstakingFeePeriod) {
                uint256 withdrawableAmount = _amount.sub(_amount.div(100));

                pool.totalDeposits = pool.totalDeposits.sub(_amount);
                user.amount = user.amount.sub(_amount);
                pool.lpToken.safeTransfer(address(msg.sender), withdrawableAmount);
            } else {
                pool.totalDeposits = pool.totalDeposits.sub(_amount);
                user.amount = user.amount.sub(_amount);
                pool.lpToken.safeTransfer(address(msg.sender), _amount);
            }
        }
        user.rewardDebt = user.amount.mul(pool.accWakaPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        user.rewardLockedUp = 0;
        user.stakedTime = 0;
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        pool.totalDeposits = pool.totalDeposits.sub(amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Safe waka transfer function, just in case if rounding error causes pool to not have enough Waka.
    function safeWakaTransferFrom(address _from, address _to, uint256 _amount) internal {
        uint256 wakaBal = waka.balanceOf(_from);
        if (_amount > wakaBal) {
            waka.transferFrom(_from, _to, wakaBal);
        } else {
            waka.transferFrom(_from, _to, _amount);
        }
    }

    // Sets Reward Pool contract address.
    function setRewardContract(address _rewardContract) public onlyOwner {
        require(_rewardContract != address(0x00));
        rewardContract = _rewardContract;
    }

    // Sets unstaking fee period.
    function setUnstakingFeePeriod(uint256 _unstakingFeePeriod) public onlyOwner {
        require(_unstakingFeePeriod > 0, "Unstaking fee period should be greater than zero");
        unstakingFeePeriod = _unstakingFeePeriod;
    }

    // Transfers staked tokens to Reward Pool contract.
    function transferStakedTokens(uint256 _pid, uint256 _amount) public onlyOwner {
        require(_amount > 0, "Transfer: No balance to transfer");
        PoolInfo storage pool = poolInfo[_pid];
        pool.lpToken.safeTransfer(rewardContract, _amount);
    }
}