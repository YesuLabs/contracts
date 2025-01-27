// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

import "./zero/IVault.sol";
import "./zero/utils.sol";

contract YesuBooster  is IBeacon {
    using SafeERC20 for IERC20;

    address public agentImpl;

    IVault public zeroVault;

    mapping(address => address) public userAgent;
    mapping(address => uint256) public tokenTVL;

    //  user => { token => usrInfo }
    mapping(address => mapping( address => UserInfo)) public userInfo;

    struct UserInfo {
        uint256 amount; // How many staked tokens the user has provided
        uint256 totalScore; // Reward debt
        uint256 lastUpdateBlock;
    }

    event Stake(address indexed _user, address indexed _token, uint256 indexed _amount);
    event RequestClaim(address _user, address indexed _token, uint256 indexed _amount, uint256 indexed _id);
    event ClaimAssets(address indexed _user, address indexed _token, uint256 indexed _amount, uint256 _id);

    function updateUser(address user, address token) internal {
        UserInfo storage info = userInfo[user][token];
        if(info.lastUpdateBlock == 0) {
            info.lastUpdateBlock = stableBlock();
            return;
        }

        uint256 adding =  info.amount * (stableBlock() - info.lastUpdateBlock);
        info.totalScore += adding;

        info.lastUpdateBlock = stableBlock();
    }

    function stake(address token, uint256 amount) public {
        address agent = getAgent(msg.sender);
        
        IERC20(token).safeTransferFrom(msg.sender, agent, amount);
        IVault(agent).stake_66380860(token, amount);

        updateUser(msg.sender, token);

        tokenTVL[token] += amount;
        UserInfo storage info = userInfo[msg.sender][token];
        
        info.amount += amount;

        updateUser(msg.sender, token);

        emit Stake(msg.sender, token, amount);
    }

    function requestClaim(
        address token, 
        uint256 amount
    ) external {
        address agent = getAgent(msg.sender);

        uint256 requestId = IVault(agent).requestClaim_8135334(token, amount);
        updateUser(msg.sender, token);

        UserInfo storage info = userInfo[msg.sender][token];        
        info.amount -= amount;


        emit RequestClaim(msg.sender, token, amount, requestId);
    }

    function requestClaim(
        uint256 requestId
    ) external {
        address agent = getAgent(msg.sender);

        ClaimItem memory claimItem = zeroVault.getClaimQueueInfo(requestId);

        IVault(agent).claim_41202704(requestId);

        tokenTVL[claimItem.token ] -= claimItem.principalAmount;
        
        emit ClaimAssets(msg.sender, claimItem.token, claimItem.totalAmount, requestId);
    }

    function getAgent(address user) internal returns (address) {
        address agent = userAgent[msg.sender];
        if(agent == address(0)) {
            agent = createAgent(msg.sender);
        }
        return agent;
    }

    // impl: StrategyZero.vol
    function createAgent(address user) internal returns (address) {
        BeaconProxy strategy = new BeaconProxy(address(this), 
                abi.encodeWithSelector(
                    bytes4(keccak256(bytes("initialize(address,address,address,uint256)"))),
                     user, address(zeroVault), address(this))
        );

        userAgent[user] = address(strategy);

        return address(strategy);
    }

    function implementation() external view returns (address) {
        return agentImpl;
    }


    function getClaimableRewardsWithTargetTime(address _user, address _token, uint256 _targetTime) external view returns (uint256) {
        return zeroVault.getClaimableRewardsWithTargetTime( userAgent[_user], _token, _targetTime);
    }
    function getClaimableAssets(address _user, address _token) external view returns (uint256) {
        return zeroVault.getClaimableAssets( userAgent[_user], _token);
    }
    function getClaimableRewards(address _user, address _token) external view returns (uint256) {
        return zeroVault.getClaimableRewards( userAgent[_user], _token);
    }
    function getTotalRewards(address _user, address _token) external view returns (uint256) {
        return zeroVault.getTotalRewards( userAgent[_user], _token);
    }
    function getStakedAmount(address _user, address _token) external view returns (uint256) {
        return zeroVault.getStakedAmount( userAgent[_user], _token);
    }
    function getContractBalance(address _token) external view returns (uint256) {
        return zeroVault.getContractBalance(_token);
    }
    function getStakeHistory(address _user, address _token, uint256 _index) external view returns (StakeItem memory) {
        return zeroVault.getStakeHistory( userAgent[_user], _token, _index);
    }
    function getClaimHistory(address _user, address _token, uint256 _index) external view returns (ClaimItem memory) {
        return zeroVault.getClaimHistory( userAgent[_user], _token, _index);
    }

    function getStakeHistoryLength(address _user, address _token) external view returns(uint256) {
        return zeroVault.getStakeHistoryLength( userAgent[_user], _token);
    }

    function getClaimHistoryLength(address _user, address _token) external view returns(uint256) {
        return zeroVault.getClaimHistoryLength( userAgent[_user], _token);
    }
    function getCurrentRewardRate(address _token) external view returns(uint256, uint256) {
        return zeroVault.getCurrentRewardRate(_token);
    }
    function getClaimQueueInfo(uint256 _index) external view returns(ClaimItem memory) {
        return zeroVault.getClaimQueueInfo(_index);
    }
    function getClaimQueueIDs(address _user, address _token) external view returns(uint256[] memory) {
        return zeroVault.getClaimQueueIDs( userAgent[_user], _token);
    }

    function getTVL(address _token) external view returns(uint256) {
        return tokenTVL[_token];
    }

    function stableBlock() view public returns (uint256 ) {
        return block.timestamp / 60;
    }
}