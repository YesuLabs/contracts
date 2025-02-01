# YesuBooster Contract

## Overview
The `YesuBooster` contract is designed to manage staking and reward distribution for users. It interacts with ERC20 tokens and a vault contract to facilitate these operations.

## External Functions

### `stake(address token, uint256 amount)`

Allows a user to stake a specified amount of a token.

- **Parameters:**
  - `token`: The address of the token to stake.
  - `amount`: The amount of the token to stake.

- **Events:**
  - `Stake(address indexed user, address indexed token, uint256 amount)`: Emitted when a user stakes tokens.

### `requestClaim(address token, uint256 amount)`

Allows a user to request a claim for a specified amount of a token.

- **Parameters:**
  - `token`: The address of the token to claim.
  - `amount`: The amount of the token to claim.

### `claim(address token)`

Allows a user to claim their rewards for a specific token.

- **Parameters:**
  - `token`: The address of the token to claim rewards for.

### `getTVL(address _token)`

Returns the total value locked (TVL) for a specific token.

- **Parameters:**
  - `_token`: The address of the token.

- **Returns:**
  - `uint256`: The total value locked for the token.

### `stableBlock()`

Returns the current block timestamp divided by 60.

- **Returns:**
  - `uint256`: The current block timestamp divided by 60.

### `getStakeHistoryLength(address _user, address _token)`

Returns the length of the stake history for a user and token.

- **Parameters:**
  - `_user`: The address of the user.
  - `_token`: The address of the token.

- **Returns:**
  - `uint256`: The length of the stake history.

### `getClaimHistoryLength(address _user, address _token)`

Returns the length of the claim history for a user and token.

- **Parameters:**
  - `_user`: The address of the user.
  - `_token`: The address of the token.

- **Returns:**
  - `uint256`: The length of the claim history.

### `getClaimableRewardsWithTargetTime(address _user, address _token, uint256 _targetTime)`

Returns the claimable rewards for a user for a specific token at a target time.

- **Parameters:**
  - `_user`: The address of the user.
  - `_token`: The address of the token.
  - `_targetTime`: The target time for calculating rewards.

- **Returns:**
  - `uint256`: The claimable rewards.

### `getClaimableAssets(address _user, address _token)`

Returns the claimable assets for a user for a specific token.

- **Parameters:**
  - `_user`: The address of the user.
  - `_token`: The address of the token.

- **Returns:**
  - `uint256`: The claimable assets.

### `getClaimableRewards(address _user, address _token)`

Returns the claimable rewards for a user for a specific token.

- **Parameters:**
  - `_user`: The address of the user.
  - `_token`: The address of the token.

- **Returns:**
  - `uint256`: The claimable rewards.

### `implementation()`

Returns the address of the implementation contract.

- **Returns:**
  - `address`: The address of the implementation contract.

## Data Structures

### `UserInfo`

A struct that holds information about a user's staking details.

- **Properties:**
  - `amount`: The amount of tokens staked by the user.
  - `totalScore`: The total score accumulated by the user.
  - `lastUpdateBlock`: The block number when the user's information was last updated.

## Example Usage

```solidity
// Example of staking tokens
YesuBooster yesuBooster = YesuBooster(yesuBoosterAddress);
yesuBooster.stake(tokenAddress, amount);

// Example of requesting a claim
yesuBooster.requestClaim(tokenAddress, amount);

// Example of claiming rewards
yesuBooster.claim(tokenAddress);

// Example of getting TVL
uint256 tvl = yesuBooster.getTVL(tokenAddress);

// Example of getting stable block
uint256 stableBlock = yesuBooster.stableBlock();

// Example of getting stake history length
uint256 stakeHistoryLength = yesuBooster.getStakeHistoryLength(userAddress, tokenAddress);

// Example of getting claim history length
uint256 claimHistoryLength = yesuBooster.getClaimHistoryLength(userAddress, tokenAddress);

// Example of getting claimable rewards with target time
uint256 claimableRewards = yesuBooster.getClaimableRewardsWithTargetTime(userAddress, tokenAddress, targetTime);

// Example of getting claimable assets
uint256 claimableAssets = yesuBooster.getClaimableAssets(userAddress, tokenAddress);

// Example of getting claimable rewards
uint256 claimableRewards = yesuBooster.getClaimableRewards(userAddress, tokenAddress);

// Example of getting implementation address
address implAddress = yesuBooster.implementation();