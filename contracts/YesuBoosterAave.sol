// SPDX-License-Identifier: MIT
pragma solidity =0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@aave/core-v3/contracts/interfaces/IPool.sol";
import "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/**
 * @title YesuBoosterAave
 * @dev A contract that allows users to stake tokens and earn rewards through Aave V3.
 */
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

    /**
     * @dev Initializes the contract with the given Aave Pool Addresses Provider.
     * @param _addressesProvider The address of the Aave Pool Addresses Provider.
     */
    function  initialize(address _addressesProvider) public initializer {

        __Ownable_init(msg.sender);

        ADDRESSES_PROVIDER = IPoolAddressesProvider(_addressesProvider);
        POOL = IPool(ADDRESSES_PROVIDER.getPool());
    }

    /**
     * @dev Returns the address of the Aave Pool Addresses Provider.
     * @return The address of the Aave Pool Addresses Provider.
     */
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

          // 2. approve Token to Aave Pool 
        IERC20(token).safeIncreaseAllowance(address(POOL), amount);

        // 3. stake Token to Aave V3 and get Atoken
        POOL.supply(address(token), amount, address(this), 0);

        // 4. calc user shares 
        address A_TOKEN = getAToken(token);

        uint256 aTokenBalance = IERC20( A_TOKEN ).balanceOf(address(this));
        uint256 totalShares_ = totalShare[token];
        uint256 shares = (totalShares_ == 0) ? amount : (amount * totalShares_) / (aTokenBalance - amount);

        totalShare[token] += shares;

        UserInfo storage info = userInfo[token][msg.sender];
        info.share  += shares;

        emit Stake(msg.sender, token, amount);
    }

    /**
     * @dev Allows a user to withdraw a specified amount of shares.
     * @param token The address of the token to withdraw.
     * @param shares The amount of shares to withdraw.
     */
     function withdraw(address token, uint256 shares) external {

        UserInfo storage info = userInfo[token][msg.sender];
        require(info.share > 0 && info.share >= shares, "Invalid shares");

        updateUser(msg.sender, token);
        uint256 totalShare_ = totalShare[token];
        IERC20 A_TOKEN =  IERC20( getAToken(token));
        // 1. withdraw aToken amount
        uint256 aTokenAmount = (shares * A_TOKEN.balanceOf(address(this))) / totalShare_;

        // 2. withdraw Token from Aave V3 
        POOL.withdraw(address(token), aTokenAmount, address(this));

        // 3. transfer Token to User 
        uint256 tokenBalance = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(msg.sender, tokenBalance);

        // 4. update shares
        info.share -= shares;
        totalShare[token] -= shares;


        emit Withdraw(msg.sender, token, tokenBalance);
    }

    /**
     * @dev Returns the user's score for a specific token.
     * @param user The address of the user.
     * @param token The address of the token.
     * @return The user's score.
     */
    function userScore(address user, address token) internal view returns (uint256) {
        UserInfo storage info = userInfo[token][user];
        if(info.lastUpdateBlock == 0) {
            return 0;
        }

        uint256 adding =  info.share * (stableBlock() - info.lastUpdateBlock);
        return info.totalScore + adding;
    }

    /**
     * @dev Returns the total assets (USDT + interest) held by the contract.
     * @return The total assets held by the contract.
     */
    function totalAssets() public view returns (uint256) {
        (uint256 totalCollateralBase,,,,,) = POOL.getUserAccountData(address(this));
        // return POOL.getUserAccountData(address(this)).totalCollateralBase;

        return totalCollateralBase;
    }

    /**
     * @dev Returns the user's token assets for a specific token.
     * @param token The address of the token.
     * @param user The address of the user.
     * @return The user's token assets.
     */
    function userTokenAssets(address token, address user) public view returns (uint256) {
        UserInfo storage info = userInfo[token][user];
        if (info.share == 0 ) {
            return 0;
        }

        uint256 totalShare_ = totalShare[token];
        IERC20 A_TOKEN =  IERC20( getAToken(token));

        return (info.share * A_TOKEN.balanceOf(address(this))) / totalShare_;
    }

    /**
     * @dev Returns the total value locked (TVL) for a specific token.
     * @param _token The address of the token.
     * @return The total value locked for the token.
     */
    function getTVL(address _token) external view returns(uint256) {
        return IERC20( getAToken(_token) ).balanceOf(address(this));
    }

    /**
     * @dev Returns the stable block number.
     * @return The stable block number.
     */
    function stableBlock() view public returns (uint256 ) {
        return block.timestamp / 10;
    }
    
    /**
     * @dev Returns the address of the aToken for a specific token.
     * @param token The address of the token.
     * @return The address of the aToken.
     */
    function getAToken(address token) public view returns(address) {
        return POOL.getReserveData(token).aTokenAddress;
    }

    /**
     * @dev Allows the owner to refund mistakenly sent tokens.
     * @param token The address of the token to refund.
     * @param to The address to send the refunded tokens to.
     * @param amount The amount of tokens to refund.
     */
    function refoundMisToken(address token, address to, uint256 amount) external onlyOwner {
        
        if (token == address(0)) {
            payable(to).transfer(amount);
        } else {
            IERC20(token).transfer(to, amount);
        }
    }

}