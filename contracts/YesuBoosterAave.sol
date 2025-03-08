// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@aave/core-v3/contracts/interfaces/IPool.sol";
import "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract YesuBoosterAave  is  OwnableUpgradeable {

    using SafeERC20 for IERC20;

    // Aave V3 Pool Addresses Provider
    IPoolAddressesProvider public ADDRESSES_PROVIDER;
    IPool public POOL;


    mapping(address => uint256) public totalShare;

    //  user => { token => usrInfo }
    mapping(address => mapping( address => UserInfo)) public userInfo;

    struct UserInfo {
        // uint256 amount; // How many staked tokens the user has provided
        uint256 totalScore; // Reward debt
        uint256 share; // aave Share
        uint256 lastUpdateBlock;
    }

    
    event Stake(address indexed _user, address indexed _token, uint256 indexed _amount);
    event Withdraw(address indexed _user, address indexed _token, uint256 indexed _amount);
    function  initialize(address _addressesProvider) public initializer {

        __Ownable_init(msg.sender);

        ADDRESSES_PROVIDER = IPoolAddressesProvider(_addressesProvider);
        POOL = IPool(ADDRESSES_PROVIDER.getPool());
    }

    function getProvider() public view returns (address) {
        return address(ADDRESSES_PROVIDER);
    }

    /**
     * @dev Updates the user's information for a specific token.
     * @param user The address of the user.
     * @param token The address of the token.
     */
    function updateUser(address user, address token) internal {
        UserInfo storage info = userInfo[user][token];
        if(info.lastUpdateBlock == 0) {
            info.lastUpdateBlock = stableBlock();
            return;
        }

        uint256 adding =  info.share * (stableBlock() - info.lastUpdateBlock);
        info.totalScore += adding;

        info.lastUpdateBlock = stableBlock();
    }

    /**
     * @dev Allows a user to stake a specified amount of a token.
     * @param token The address of the token to stake.
     * @param amount The amount of the token to stake.
     */
    function stake(address token, uint256 amount) external {
        
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        updateUser(msg.sender, token);

          // 2. 授权 Aave Pool 使用 USDT
        IERC20(token).safeIncreaseAllowance(address(POOL), amount);

        // 3. 存入 Aave V3，并获取 aToken
        POOL.supply(address(token), amount, address(this), 0);

        // 4. 按比例更新用户份额（简化逻辑，实际需计算 aToken 数量）
        address A_TOKEN = getAToken(token);

        uint256 aTokenBalance = IERC20( A_TOKEN ).balanceOf(address(this));
        uint256 totalShares_ = totalShare[token];
        uint256 shares = (totalShares_ == 0) ? amount : (amount * totalShares_) / (aTokenBalance - amount);

        totalShare[token] += shares;

        UserInfo storage info = userInfo[token][msg.sender];
        info.share  += shares;

        emit Stake(msg.sender, token, amount);
    }

     function withdraw(address token, uint256 shares) external {

        UserInfo storage info = userInfo[token][msg.sender];
        require(info.share > 0 && info.share >= shares, "Invalid shares");

        updateUser(msg.sender, token);
        uint256 totalShare_ = totalShare[token];
        IERC20 A_TOKEN =  IERC20( getAToken(token));
        // 1. 计算可提取的 aToken 数量
        uint256 aTokenAmount = (shares * A_TOKEN.balanceOf(address(this))) / totalShare_;

        // 2. 从 Aave V3 提取 USDT
        POOL.withdraw(address(token), aTokenAmount, address(this));

        // 3. 转账 USDT 给用户
        uint256 tokenBalance = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(msg.sender, tokenBalance);

        // 4. 更新份额
        info.share -= shares;
        totalShare[token] -= shares;


        emit Withdraw(msg.sender, token, tokenBalance);
    }

    function userScore(address user, address token) internal view returns (uint256) {
        UserInfo storage info = userInfo[token][user];
        if(info.lastUpdateBlock == 0) {
            return 0;
        }

        uint256 adding =  info.share * (stableBlock() - info.lastUpdateBlock);
        return info.totalScore + adding;
    }

    // 获取当前总资产（USDT + 利息）
    function totalAssets() public view returns (uint256) {
        (uint256 totalCollateralBase,,,,,) = POOL.getUserAccountData(address(this));
        // return POOL.getUserAccountData(address(this)).totalCollateralBase;

        return totalCollateralBase;
    }

    function userTokenAssets(address token, address user) public view returns (uint256) {
        UserInfo storage info = userInfo[token][user];
        if (info.share == 0 ) {
            return 0;
        }

        uint256 totalShare_ = totalShare[token];
        IERC20 A_TOKEN =  IERC20( getAToken(token));

        return (info.share * A_TOKEN.balanceOf(address(this))) / totalShare_;
    }


    function getTVL(address _token) external view returns(uint256) {
        return IERC20( getAToken(_token) ).balanceOf(address(this));
    }

    function stableBlock() view public returns (uint256 ) {
        return block.timestamp / 10;
    }
    
    function getAToken(address token) public view returns(address) {
        return POOL.getReserveData(token).aTokenAddress;
    }

    function refoundMisToken(address token, address to, uint256 amount) external onlyOwner {
        
        if (token == address(0)) {
            payable(to).transfer(amount);
        } else {
            IERC20(token).transfer(to, amount);
        }
    }

}