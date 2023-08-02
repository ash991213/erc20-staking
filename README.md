## Simple ERC20 Token Staking Contract

- This is a staking contract that allows users to deposit ERC20 tokens and receive other ERC20 tokens as rewards on the blockchain.

- When depositing tokens, users can choose the duration of 30, 60, or 90 days, and receive rewards tokens at rates of 10%, 25%, and 50% respectively.

- Users can only deposit an amount within the specified minimum and maximum stake limits.

- Additional deposits can be made within the maximum stake limit.

- When receiving staking rewards, the staking rewards are updated and the last update time is changed.

## Components

### stakingToken

- The staking token (ERC20) used for staking.

### rewardToken

- The reward token (ERC20) distributed as staking rewards.

### minStake / maxStake

- The minimum and maximum amounts that can be staked.

### StakingType

- An enumeration of staking types.

### StakingPeriod

- A struct representing the staking periods. rateOne, rateTwo, and rateThree correspond to 30 days, 60 days, and 90 days respectively.

### ReturnRate

- A struct representing the return rates. rateOne, rateTwo, and rateThree correspond to 10%, 25%, and 50% respectively.

### StakingInfo

- A struct representing the staking information. deposited represents the deposited amount, firstAt is the initial staking time, updateAt is the last update time, and rewards represents the pending staking rewards.

### hourInSeconds

- A constant used to calculate time in seconds.

### stakers

- A mapping to store the staking information for each staker.

## Considerations

- Prevent reentrancy attacks using the nonReentrant modifier.

- Use the SafeMath library to prevent overflow/underflow when calculating staking rewards.

- The staking token and reward token are immutable and their values cannot be changed.

- Stakers must send an amount greater than or equal to the minimum stake amount to the staking contract. Additionally, amounts outside the range of the minimum and maximum stake limits cannot be deposited.

- When staking, stakers need to specify the staking type, which determines the staking period and reward rate.

- Stakers can stake for 30, 60, or 90 days starting from the initial staking time for each staking type.

- Stakers must stake at least once for each staking type. For example, if a staker has staked for 30 days, they need to stake again to participate in the 60-day staking.

- Stakers can make additional deposits within the maximum stake limit. After the previous staking ends and all pending rewards are claimed, stakers can stake again.

- Stakers can partially withdraw their deposited tokens. When partially withdrawing, the pending rewards are updated, and the staker receives rewards proportional to the remaining token amount.

- Stakers receive rewards only for the staking period specified by the staking type. For example, if a staker has staked for 30 days and claims rewards after 40 days, they will only receive rewards for the initial 30-day period.

## Staking Process

1. Stakers delegate (approve) the tokens they want to stake to the smart contract.

2. Stakers call the stake function to stake tokens. They specify the amount to stake (_amount) and the staking type (_type). The amount (_amount) must be within the minimum and maximum stake limits.

2-1. If there is an ongoing staking, stakers can make additional deposits within the maximum stake limit.

2-2. When staking again, if there are pending rewards, the rewards are forfeited. If all rewards have been claimed, the staking information is reset, and the staker can stake again.

3. Stakers can claim their rewards by calling the claimReward function. They specify the staking type (_type) to claim rewards from a specific staking type. Only rewards from one staking type can be claimed at a time. Even if the staking period (30 days, 60 days, 90 days) is not completed, stakers can claim rewards for the duration from the initial staking time to the current time.

4. Stakers can unstake by using the unstake function. They specify the staking type (_type) to unstake from a specific staking type. After unstaking and receiving the staking tokens, stakers can claim rewards by calling the claimReward function.

## Security analysis

- MythX

![스크린샷 2023-08-02 오전 11 06 01](https://github.com/ash991213/ERC20-Staking/assets/99451647/d16ead9a-e370-4c1c-8539-08d256432730)


