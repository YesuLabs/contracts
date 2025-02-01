// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

// Main information: stake and claim
struct AssetsInfo {
    uint256 stakedAmount;
    uint256 accumulatedReward;
    uint256 lastRewardUpdateTime;
    uint256[] pendingClaimQueueIDs;
    StakeItem[] stakeHistory;
    ClaimItem[] claimHistory;
}
struct StakeItem {
    address token;
    address user;
    uint256 amount;
    uint256 stakeTimestamp;
}
struct ClaimItem {
    bool isDone;
    address token;
    address user;
    uint256 totalAmount;
    uint256 principalAmount;
    uint256 rewardAmount;
    uint256 requestTime;
    uint256 claimTime;
}

interface IVault {
    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///                                             events                                                ///
    /////////////////////////////////////////////////////////////////////////////////////////////////////////

    event Stake(address indexed _user, address indexed _token, uint256 indexed _amount);
    event RequestClaim(address _user, address indexed _token, uint256 indexed _amount, uint256 indexed _id);
    event ClaimAssets(address indexed _user, address indexed _token, uint256 indexed _amount, uint256 _id);
    event UpdateRewardRate(address _token, uint256 _oldRewardRate, uint256 _newRewardRate);
    event UpdateCeffu(address _oldCeffu, address _newCeffu);
    event UpdateStakeLimit(address indexed _token, uint256 _oldMinAmount, uint256 _oldMaxAmount, uint256 _newMinAmount, uint256 _newMaxAmount);
    event CeffuReceive(address indexed _token, address _ceffu, uint256 indexed _amount);
    event AddSupportedToken(address indexed _token, uint256 _minAmount, uint256 _maxAmount);
    event EmergencyWithdrawal(address indexed _token, address indexed _receiver);
    event UpdateWaitingTime(uint256 _oldWaitingTime, uint256 _newWaitingTIme);

    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///                                             write                                                 ///
    /////////////////////////////////////////////////////////////////////////////////////////////////////////

    function stake_66380860(address _token, uint256 _stakedAmount) external;
    function requestClaim_8135334(address _token, uint256 _amount) external returns(uint256);
    function claim_41202704(uint256 _queueID) external;

    function transferToCeffu(address _token, uint256 _amount) external;
    function emergencyWithdraw(address _token, address _receiver) external;

    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///                                        configuration                                              ///
    /////////////////////////////////////////////////////////////////////////////////////////////////////////

    function addSupportedToken(address _token, uint256 _minAmount, uint256 _maxAmount) external;
    function setRewardRate(address _token, uint256 _newRewardRate) external;
    function setStakeLimit(address _token, uint256 _minAmount, uint256 _maxAmount) external;
    function setCeffu(address _newCeffu) external;
    function setWaitingTime(uint256 _newWaitingTIme) external;

    /////////////////////////////////////////////////////////////////////////////////////////////////////////
    ///                                          view / pure                                              ///
    /////////////////////////////////////////////////////////////////////////////////////////////////////////

    function getClaimableRewardsWithTargetTime(address _user, address _token, uint256 _targetTime) external view returns (uint256);
    function getClaimableAssets(address _user, address _token) external view returns (uint256);
    function getClaimableRewards(address _user, address _token) external view returns (uint256);
    function getTotalRewards(address _user, address _token) external view returns (uint256);
    function getStakedAmount(address _user, address _token) external view returns (uint256);
    function getContractBalance(address _token) external view returns (uint256);
    function getStakeHistory(address _user, address _token, uint256 _index) external view returns (StakeItem memory);
    function getClaimHistory(address _user, address _token, uint256 _index) external view returns (ClaimItem memory);
    function getStakeHistoryLength(address _user, address _token) external view returns(uint256);
    function getClaimHistoryLength(address _user, address _token) external view returns(uint256);
    function getCurrentRewardRate(address _token) external view returns(uint256, uint256);
    function getClaimQueueInfo(uint256 _index) external view returns(ClaimItem memory);
    function getClaimQueueIDs(address _user, address _token) external view returns(uint256[] memory);
    function getTVL(address _token) external view returns(uint256);
}