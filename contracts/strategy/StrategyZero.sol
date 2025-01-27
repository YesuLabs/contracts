// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

import "../zero/IVault.sol";


contract StrategyZero  {

    IVault public zeroVault;
    address public factory;
    address public userOwner;

    modifier onlyFactory() {
        require(msg.sender == factory, "Caller only factory");
        _;
    }

    function initialize(address _zeroVault, address _userOwner) public {
        zeroVault = IVault(_zeroVault);

        userOwner = _userOwner;
    }

    function stake_66380860(address _token, uint256 _stakedAmount) external onlyFactory {

        IERC20(_token).approve(address(zeroVault), _stakedAmount);

        zeroVault.stake_66380860(_token, _stakedAmount);
    }

    function requestClaim_8135334(address _token, uint256 _amount) external onlyFactory() returns(uint256) {
        return zeroVault.requestClaim_8135334(_token, _amount);
    }
    function claim_41202704(uint256 _queueID) external {
        ClaimItem memory claimItem = zeroVault.getClaimQueueInfo(_queueID);
        address token = claimItem.token;

        zeroVault.claim_41202704(_queueID);

        uint256 bal = IERC20(token).balanceOf(address(this));

        IERC20(token).transfer(userOwner, bal);
    }

    function emergencyWithdraw(address _token, address _receiver) external onlyFactory() {
        zeroVault.emergencyWithdraw(_token, _receiver);
    }

}