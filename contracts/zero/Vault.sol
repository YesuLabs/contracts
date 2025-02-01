// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import "./IVault.sol";
import "./utils.sol";

contract Vault is Pausable, AccessControl, IVault {
    using SafeERC20 for IERC20;

    mapping(address => uint256) private tvl;

    // Supported tokens list
    mapping(address => bool) public supportedTokens;
    address[] private supportedTokensArray;

    // We do not start from 0 because the default queue ID for users is 0(variable default value).
    uint256 public lastClaimQueueID = 1;
    mapping(uint256 => ClaimItem) private claimQueue;

    // Main information
    mapping(address => mapping(address => AssetsInfo)) private userAssetsInfo;

    // Reward rate
    struct RewardRateState {
        address token;
        uint256 rewardRate;
        uint256 updatedTime;
    }
    mapping(address => RewardRateState[]) private rewardRateState;

    // Role
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant BOT_ROLE = keccak256("BOT_ROLE");

    // Misc
    address public ceffu;
    mapping(address => uint256) public minStakeAmount;
    mapping(address => uint256) public maxStakeAmount;
    uint256 public WAITING_TIME;
    uint256 private constant BASE = 10_000;

    constructor(
        address[] memory _tokens,
        uint256[] memory _newRewardRate,
        uint256[] memory _minStakeAmount,
        uint256[] memory _maxStakeAmount,
        address _admin,
        address _bot,
        address _ceffu,
        uint256 _waitingTime
    ) {
        Utils.CheckIsZeroAddress(_ceffu);
        Utils.CheckIsZeroAddress(_admin);
        Utils.CheckIsZeroAddress(_bot);

        uint256 len = _tokens.length;
        require(Utils.MustGreaterThanZero(len), "Array length can NOT be zero");
        require(
            len == _newRewardRate.length &&
            len == _minStakeAmount.length &&
            len == _maxStakeAmount.length,
            "The lengths of the arrays MUST be the same"
        );

        // Grant role
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
        _grantRole(BOT_ROLE, _bot);

        ceffu = _ceffu;
        emit UpdateCeffu(address(0), _ceffu);

        WAITING_TIME = _waitingTime;
        emit UpdateWaitingTime(0, _waitingTime);

        // Set the supported tokens and reward rate
        for (uint256 i = 0; i < len; i++) {
            require(_minStakeAmount[i] < _maxStakeAmount[i], "minAmount MUST be less than maxAmount");

            // supported tokens
            address token = _tokens[i];
            minStakeAmount[token] = _minStakeAmount[i];
            maxStakeAmount[token] = _maxStakeAmount[i];
            supportedTokens[token] = true;
            supportedTokensArray.push(token);
            emit AddSupportedToken(token, _minStakeAmount[i], _maxStakeAmount[i]);

            // reward rate
            RewardRateState memory rewardRateItem = RewardRateState({
                token: token,
                rewardRate: _newRewardRate[i],
                updatedTime: block.timestamp
            });
            rewardRateState[token].push(rewardRateItem);
            emit UpdateRewardRate(token, 0, _newRewardRate[i]);
        }
    }

    modifier onlySupportedToken(address _token) {
        require(supportedTokens[_token], "Unsupported token");
        _;
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///                                             write                                                 ///
    /////////////////////////////////////////////////////////////////////////////////////////////////////////

    // function signature: 000000ed, the less function matching, the more gas saved
    function stake_66380860(address _token,  uint256 _stakedAmount) external onlySupportedToken(_token) whenNotPaused {
        AssetsInfo storage assetsInfo = userAssetsInfo[msg.sender][_token];
        uint256 currentStakedAmount = assetsInfo.stakedAmount;

        require(Utils.Add(currentStakedAmount, _stakedAmount) >= minStakeAmount[_token], "Amount MUST be greater than minStakeAmount");
        require(Utils.Add(currentStakedAmount, _stakedAmount) <= maxStakeAmount[_token], "The deposit amount MUST NOT exceed maxStakeAmount");

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _stakedAmount);

        _updateRewardState(msg.sender, _token);

        // update status
        assetsInfo.stakeHistory.push(
            StakeItem({
                stakeTimestamp: block.timestamp,
                amount: _stakedAmount,
                token: _token,
                user: msg.sender
            })
        );
        unchecked {
            assetsInfo.stakedAmount += _stakedAmount;
            tvl[_token] += _stakedAmount;
        }

        emit Stake(msg.sender, _token, _stakedAmount);
    }

    // function signature: 0000004e, the less function matching, the more gas saved
    function requestClaim_8135334(
        address _token, 
        uint256 _amount
    ) external onlySupportedToken(_token) whenNotPaused returns(uint256 _returnID) {
        _updateRewardState(msg.sender, _token);

        AssetsInfo storage assetsInfo = userAssetsInfo[msg.sender][_token];
        uint256 currentStakedAmount = assetsInfo.stakedAmount;
        uint256 currentAccumulatedRewardAmount = assetsInfo.accumulatedReward;

        require(
            Utils.MustGreaterThanZero(_amount) && 
            (_amount <= Utils.Add(currentStakedAmount, currentAccumulatedRewardAmount) || _amount == type(uint256).max), 
            "Invalid amount"
        );

        ClaimItem storage queueItem = claimQueue[lastClaimQueueID];

        // Withdraw from reward first; if insufficient, continue withdrawing from principal
        uint256 totalAmount = _amount;
        if(_amount == type(uint256).max){
            totalAmount = Utils.Add(currentAccumulatedRewardAmount, assetsInfo.stakedAmount);

            queueItem.rewardAmount = currentAccumulatedRewardAmount;
            assetsInfo.accumulatedReward = 0;

            queueItem.principalAmount = assetsInfo.stakedAmount;
            assetsInfo.stakedAmount = 0;
        }else if(currentAccumulatedRewardAmount >= _amount) {
            assetsInfo.accumulatedReward -= _amount;

            queueItem.rewardAmount = _amount;
        } else {
            queueItem.rewardAmount = currentAccumulatedRewardAmount;
            assetsInfo.accumulatedReward = 0;

            uint256 difference = _amount - currentAccumulatedRewardAmount;
            assetsInfo.stakedAmount -= difference;
            queueItem.principalAmount = difference;
        }

        // update status
        assetsInfo.pendingClaimQueueIDs.push(lastClaimQueueID);

        // update queue
        queueItem.token = _token;
        queueItem.user = msg.sender;
        queueItem.totalAmount = totalAmount;
        queueItem.requestTime = block.timestamp;
        queueItem.claimTime = Utils.Add(block.timestamp, WAITING_TIME);

        unchecked {
            _returnID = lastClaimQueueID;
            ++lastClaimQueueID;
        }

        emit RequestClaim(msg.sender, _token, totalAmount, _returnID);
    }

    // function signature: 000000e5, the less function matching, the more gas saved
    function claim_41202704(uint256 _queueID) external whenNotPaused{
        ClaimItem memory claimItem = claimQueue[_queueID];
        address token = claimItem.token;
        AssetsInfo storage assetsInfo = userAssetsInfo[msg.sender][token];
        uint256[] memory pendingClaimQueueIDs = userAssetsInfo[msg.sender][token].pendingClaimQueueIDs;
        
        require(Utils.MustGreaterThanZero(claimItem.totalAmount), "No assets to claim");
        require(block.timestamp >= claimItem.claimTime, "Not enough time");
        require(claimItem.user == msg.sender, "Invalid caller");
        require(claimItem.isDone == false, "The request is completed");

        // update status
        claimQueue[_queueID].isDone = true;
        for(uint256 i = 0; i < pendingClaimQueueIDs.length; i++) {
            if(pendingClaimQueueIDs[i] == _queueID) {
                assetsInfo.pendingClaimQueueIDs[i] = pendingClaimQueueIDs[pendingClaimQueueIDs.length-1];
                assetsInfo.pendingClaimQueueIDs.pop();
                break;
            }
        }
        tvl[token] -= claimItem.principalAmount;

        assetsInfo.claimHistory.push(
            ClaimItem({
                isDone: true,
                token: token,
                user: msg.sender,
                totalAmount: claimItem.totalAmount,
                principalAmount: claimItem.principalAmount,
                rewardAmount: claimItem.rewardAmount,
                requestTime: claimItem.requestTime,
                claimTime: block.timestamp
            })
        );

        IERC20(token).safeTransfer(msg.sender, claimItem.totalAmount);

        emit ClaimAssets(msg.sender, token, claimItem.totalAmount, _queueID);
    }

    function _updateRewardState(address _user, address _token) internal {
        AssetsInfo storage assetsInfo = userAssetsInfo[msg.sender][_token];
        uint256 newAccumulatedReward = 0;
        if(assetsInfo.lastRewardUpdateTime != 0) { // not the first time to stake
            newAccumulatedReward = _getClaimableRewards(_user, _token);
        }

        assetsInfo.accumulatedReward = newAccumulatedReward;
        assetsInfo.lastRewardUpdateTime = block.timestamp;
    }

    function transferToCeffu(
        address _token,
        uint256 _amount
    ) external onlySupportedToken(_token) onlyRole(BOT_ROLE) {
        require(Utils.MustGreaterThanZero(_amount), "Amount must be greater than zero");
        require(_amount <= IERC20(_token).balanceOf(address(this)), "Not enough balance");

        IERC20(_token).safeTransfer(ceffu, _amount);

        emit CeffuReceive(_token, ceffu, _amount);
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///                                          emergency                                                ///
    /////////////////////////////////////////////////////////////////////////////////////////////////////////

    function emergencyWithdraw(address _token, address _receiver) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // `_token` could be not supported, so that we could sweep the tokens which are sent to this contract accidentally
        Utils.CheckIsZeroAddress(_token);
        Utils.CheckIsZeroAddress(_receiver);

        IERC20(_token).safeTransfer(_receiver, IERC20(_token).balanceOf(address(this)));
        emit EmergencyWithdrawal(_token, _receiver);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///                                        configuration                                              ///
    /////////////////////////////////////////////////////////////////////////////////////////////////////////

    function addSupportedToken(
        address _token,
        uint256 _minAmount,
        uint256 _maxAmount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Utils.CheckIsZeroAddress(_token);
        require(!supportedTokens[_token], "The token is already supported");

        // update the supported tokens
        supportedTokens[_token] = true;
        supportedTokensArray.push(_token);
        setStakeLimit(_token, _minAmount, _maxAmount);

        emit AddSupportedToken(_token, _minAmount, _maxAmount);
    }

    function setRewardRate(
        address _token, 
        uint256 _newRewardRate
    ) external onlySupportedToken(_token) onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_newRewardRate < BASE, "Invalid new rate");

        RewardRateState[] memory rewardRateArray = rewardRateState[_token];
        uint256 currentRewardRate = rewardRateArray[rewardRateArray.length - 1].rewardRate;
        require(currentRewardRate != _newRewardRate && Utils.MustGreaterThanZero(_newRewardRate), "Invalid new reward rate");

        // add the new reward rate to the array
        RewardRateState memory rewardRateItem = RewardRateState({
            updatedTime: block.timestamp,
            token: _token,
            rewardRate: _newRewardRate
        });
        rewardRateState[_token].push(rewardRateItem);

        emit UpdateRewardRate(_token, currentRewardRate, _newRewardRate);
    }

    function setCeffu(address _newCeffu) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Utils.CheckIsZeroAddress(_newCeffu);
        require(_newCeffu != ceffu, "Invalid new ceffu address");

        emit UpdateCeffu(ceffu, _newCeffu);
        ceffu = _newCeffu;
    }

    function setStakeLimit(
        address _token,
        uint256 _minAmount,
        uint256 _maxAmount
    ) public onlyRole(DEFAULT_ADMIN_ROLE) onlySupportedToken(_token) {
        require(Utils.MustGreaterThanZero(_minAmount) && _minAmount < _maxAmount, "Invalid limit range");

        emit UpdateStakeLimit(_token, minStakeAmount[_token], maxStakeAmount[_token], _minAmount, _maxAmount);
        minStakeAmount[_token] = _minAmount;
        maxStakeAmount[_token] = _maxAmount;
    }

    function setWaitingTime(uint256 _newWaitingTime) external onlyRole(DEFAULT_ADMIN_ROLE){
        require(_newWaitingTime != WAITING_TIME, "New waiting time should NOT be the same as the old one");

        emit UpdateWaitingTime(WAITING_TIME, _newWaitingTime);
        WAITING_TIME = _newWaitingTime;        
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///                                          view / pure                                              ///
    /////////////////////////////////////////////////////////////////////////////////////////////////////////

    function calculateReward(
        uint256 _stakedAmount, 
        uint256 _rewardRate, 
        uint256 _elapsedTime
    ) internal pure returns (uint256 result) {
        // (stakedAmount * rewardRate * elapsedTime) / (ONE_YEAR * 10000)
        // Parameter descriptions:
        // - stakedAmount: The amount staked by the user
        // - rewardRate: The annual reward rate (e.g., 700 means 7%)
        // - elapsedTime: The time interval over which the reward is calculated, in seconds
        // - ONE_YEAR: The total number of seconds in one year (365.25 days)
        assembly {
            // uint256 ONE_YEAR = uint256(365.25 * 24 * 60 * 60); // 365.25 days per year: 31557600
            let ONE_YEAR := 31557600

            // Calculate numerator = stakedAmount * rewardRate * elapsedTime
            let numerator := mul(_stakedAmount, _rewardRate)
            numerator := mul(numerator, _elapsedTime)

            // Calculate denominator = ONE_YEAR * 10000
            let denominator := mul(ONE_YEAR, BASE)

            // Perform the division result = numerator / denominator
            result := div(numerator, denominator)
        }
    }

    function _getClaimableRewards(address _user, address _token) internal view returns (uint256) {
        AssetsInfo memory assetsInfo = userAssetsInfo[_user][_token];
        uint256 currentStakedAmount = assetsInfo.stakedAmount;
        uint256 lastRewardUpdate = assetsInfo.lastRewardUpdateTime;

        RewardRateState[] memory rewardRateArray = rewardRateState[_token];
        uint256 rewardRateLength = rewardRateArray.length;
        RewardRateState memory currentRewardRateState = rewardRateArray[rewardRateLength - 1];

        if(lastRewardUpdate == 0) return 0;

        // 1. Retrieve the last deposit time `begin`
        // 2. Retrieve the current deposit time `end`
        // 3. Check whether the reward rate changed between time `begin` and time `end`
        // 4. Determine if the reward rate has changed since the last deposit:
        //    - If no changes occurred, directly calculate and add the reward.
        //    - If changes occurred, divide the deposit time into segments based on different rates 
        //      and accumulate the rewards accordingly.
        if(currentRewardRateState.updatedTime <= lastRewardUpdate){
            /*
                   begin                   end
                    |~~~~~~ position ~~~~~~~|
                |--------- reward rate 1 --------------|--------- upcoming reward rate 2 --------------|
            */

            uint256 elapsedTime = block.timestamp - assetsInfo.lastRewardUpdateTime;
            uint256 reward = calculateReward(
                currentStakedAmount,
                currentRewardRateState.rewardRate,
                elapsedTime
            );

            return assetsInfo.accumulatedReward + reward;
        } else {
            /*
                   begin                                                       end
                    |~~~~~~~~~~~~~~~~~~~~~~ position ~~~~~~~~~~~~~~~~~~~~~~~~~~~|
                |--------- reward rate 1 --------------|-- reward rate 2 --|-------- reward rate 3 --------|
            */

            // a. based on the reward rate at the time of the last stake, find the corresponding index in the rate array
            uint256 beginIndex = 0;
            for (uint256 i = 0; i < rewardRateLength; i++) {
                if (lastRewardUpdate < rewardRateArray[i].updatedTime) {
                    beginIndex = i;
                    break;
                }
            }

            // b. iterate to the latest-1 reward rate
            uint256 tempLastRewardUpdateTime = lastRewardUpdate;
            for (uint256 i = beginIndex; i < rewardRateLength; i++) {
                if(i == 0) continue;

                uint256 tempElapsedTime = rewardRateArray[i].updatedTime - tempLastRewardUpdateTime;
                uint256 tempReward = calculateReward(
                    currentStakedAmount,
                    rewardRateArray[i - 1].rewardRate,
                    tempElapsedTime
                );
                tempLastRewardUpdateTime = rewardRateArray[i].updatedTime;
                unchecked{
                    assetsInfo.accumulatedReward += tempReward;
                }
            }

            // c. the reward generated by the latest reward rate
            uint256 elapsedTime = block.timestamp - currentRewardRateState.updatedTime;
            uint256 reward = calculateReward(
                currentStakedAmount,
                currentRewardRateState.rewardRate,
                elapsedTime
            );

            return assetsInfo.accumulatedReward + reward;
        }
    }

    // principal + rewards
    function getClaimableAssets(address _user, address _token) external view returns (uint256) {
        AssetsInfo memory assetsInfo = userAssetsInfo[_user][_token];
        
        return Utils.Add(assetsInfo.stakedAmount, _getClaimableRewards(_user, _token));
    }

    // current rewards
    function getClaimableRewards(address _user, address _token) external view returns (uint256) {
        return _getClaimableRewards(_user, _token);
    }

    // history rewards + current rewards
    function getTotalRewards(address _user, address _token) external view returns (uint256) {
        uint256 historyRewards = 0;
        uint256 currentRewards = _getClaimableRewards(_user, _token);

        AssetsInfo memory stakeInfo = userAssetsInfo[_user][_token];
        for(uint256 i = 0; i < stakeInfo.claimHistory.length; i++) {
            historyRewards += stakeInfo.claimHistory[i].rewardAmount;
        }

        return Utils.Add(historyRewards, currentRewards);
    }

    // Calculate the total withdrawable amount for a user at a future time, 
    // based on the user's current staked amount and the current reward rate.
    function getClaimableRewardsWithTargetTime(
        address _user,
        address _token,
        uint256 _targetTime
    ) external view returns (uint256) {
        require(_targetTime > block.timestamp, "Invalid target time");

        AssetsInfo memory assetsInfo = userAssetsInfo[_user][_token];
        RewardRateState[] memory rewardRateArray = rewardRateState[_token];
        RewardRateState memory currentRewardRateState = rewardRateArray[rewardRateArray.length - 1];

        uint256 newAccumulatedReward = 0;
        if(assetsInfo.lastRewardUpdateTime != 0) { // not the first time to stake
            newAccumulatedReward = _getClaimableRewards(_user, _token);
        }

        uint256 elapsedTime = _targetTime - block.timestamp;
        uint256 reward = calculateReward(
            assetsInfo.stakedAmount,
            currentRewardRateState.rewardRate,
            elapsedTime
        );

        return Utils.Add(newAccumulatedReward, reward);
    }

    function getStakedAmount(address _user, address _token) external view onlySupportedToken(_token) returns (uint256) {
        AssetsInfo memory stakeInfo = userAssetsInfo[_user][_token];
        return stakeInfo.stakedAmount;
    }

    function getContractBalance(address _token) external view returns (uint256) {
        Utils.CheckIsZeroAddress(_token);
        return IERC20(_token).balanceOf(address(this));
    }

    function getStakeHistory(
        address _user,
        address _token,
        uint256 _index
    ) external view onlySupportedToken(_token) returns (StakeItem memory) {
        AssetsInfo memory stakeInfo = userAssetsInfo[_user][_token];
        require(_index < stakeInfo.stakeHistory.length, "Invalid index");

        return stakeInfo.stakeHistory[_index];
    }

    function getClaimHistory(
        address _user,
        address _token,
        uint256 _index
    ) external view onlySupportedToken(_token) returns (ClaimItem memory) {
        AssetsInfo memory stakeInfo = userAssetsInfo[_user][_token];
        require(_index < stakeInfo.claimHistory.length, "Invalid index");

        return stakeInfo.claimHistory[_index];
    }

    function getStakeHistoryLength(address _user, address _token) external view returns(uint256) {
        AssetsInfo memory stakeInfo = userAssetsInfo[_user][_token];

        return stakeInfo.stakeHistory.length;
    }
    function getClaimHistoryLength(address _user, address _token) external view returns(uint256) {
        AssetsInfo memory stakeInfo = userAssetsInfo[_user][_token];
        
        return stakeInfo.claimHistory.length;
    }

    // Check the current withdrawal request in progress for a specific user
    function getClaimQueueIDs(address _user, address _token) external view returns (uint256[] memory) {
        AssetsInfo memory assetsInfo = userAssetsInfo[_user][_token];
        return assetsInfo.pendingClaimQueueIDs;
    }

    // Measure the reward rate as a percentage, and return the numerator and denominator
    function getCurrentRewardRate(address _token) external view returns (uint256, uint256) {
        RewardRateState[] memory rewardRateStateArray = rewardRateState[_token];
        RewardRateState memory currentRewardRateState = rewardRateStateArray[rewardRateStateArray.length - 1];

        return (currentRewardRateState.rewardRate, BASE);
    }

    function getClaimQueueInfo(uint256 _index) external view returns(ClaimItem memory) {
        return claimQueue[_index];
    }

    function getTVL(address _token) external view returns(uint256){
        return tvl[_token];
    }

    receive() external payable {
        revert("No ether should be here");
    }
}