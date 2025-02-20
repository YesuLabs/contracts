// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@aave/core-v3/contracts/interfaces/IPool.sol";
import "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";

contract StrategyAAVE {
    using SafeERC20 for IERC20;

    // Aave V3 Pool Addresses Provider
    IPoolAddressesProvider public immutable ADDRESSES_PROVIDER;
    IPool public immutable POOL;

    // USDT 和对应的 aToken
    IERC20 public immutable USDT;
    IERC20 public immutable A_USDT;

    // 记录用户存入的 USDT 份额
    mapping(address => uint256) public userShares;
    uint256 public totalShares;

    // 事件
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    // network sepolia
    // 0x012bAC54348C0E635dCAc9D5FB99f06F24136C9A - addressesProvider
    // 0xaa8e23fb1079ea71e0a56f48a2aa51851d8433d0 - usdt
    // 0xaf0f6e8b0dc5c913bbf4d14c22b4e78dd14310b6 - aUsdt
    constructor(
        address _addressesProvider,
        address _usdt,
        address _aUsdt
    ) {
        ADDRESSES_PROVIDER = IPoolAddressesProvider(_addressesProvider);
        POOL = IPool(ADDRESSES_PROVIDER.getPool());
        USDT = IERC20(_usdt);
        A_USDT = IERC20(_aUsdt);
    }

    // 存入 USDT
    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        
        // 1. 从用户转账 USDT 到合约
        USDT.safeTransferFrom(msg.sender, address(this), amount);

        // 2. 授权 Aave Pool 使用 USDT
        USDT.safeIncreaseAllowance(address(POOL), amount);

        // 3. 存入 Aave V3，并获取 aToken
        POOL.supply(address(USDT), amount, address(this), 0);

        // 4. 按比例更新用户份额（简化逻辑，实际需计算 aToken 数量）
        uint256 aTokenBalance = A_USDT.balanceOf(address(this));
        uint256 shares = (totalShares == 0) ? amount : (amount * totalShares) / (aTokenBalance - amount);
        userShares[msg.sender] += shares;
        totalShares += shares;

        emit Deposited(msg.sender, amount);
    }

    // 提取 USDT（按份额比例提取本金+收益）
    function withdraw(uint256 shares) external {
        require(shares > 0 && userShares[msg.sender] >= shares, "Invalid shares");

        // 1. 计算可提取的 aToken 数量
        uint256 aTokenAmount = (shares * A_USDT.balanceOf(address(this))) / totalShares;

        // 2. 从 Aave V3 提取 USDT
        POOL.withdraw(address(USDT), aTokenAmount, address(this));

        // 3. 转账 USDT 给用户
        uint256 usdtBalance = USDT.balanceOf(address(this));
        USDT.safeTransfer(msg.sender, usdtBalance);

        // 4. 更新份额
        userShares[msg.sender] -= shares;
        totalShares -= shares;

        emit Withdrawn(msg.sender, usdtBalance);
    }

    // 获取当前总资产（USDT + 利息）
    function totalAssets() public view returns (uint256) {
        (uint256 totalCollateralBase,,,,,) = POOL.getUserAccountData(address(this));
        // return POOL.getUserAccountData(address(this)).totalCollateralBase;

        return totalCollateralBase;
    }

    function userAssets(address user) public view returns (uint256) {
        if(totalShares == 0) { return 0; }
        (uint256 totalCollateralBase,,,,,) = POOL.getUserAccountData(user);
        return totalCollateralBase * userShares[user] / totalShares;
    }
}