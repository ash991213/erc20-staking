const timeTraveler = require('ganache-time-traveler');
const Staking = artifacts.require('Staking');
const TestToken = artifacts.require('TestToken');
const Web3 = require('web3');
const web3 = new Web3(new Web3(new Web3.providers.HttpProvider('http://127.0.0.1:8545')));

const decimals = web3.utils.toBN('18');
const minStakeInWei = web3.utils.toBN('1000').mul(web3.utils.toBN(10).pow(decimals));
const maxStakeInWei = web3.utils.toBN('1000000').mul(web3.utils.toBN(10).pow(decimals));
const unStakeInWei = web3.utils.toBN('999000').mul(web3.utils.toBN(10).pow(decimals));
const REWARDS_ONE_HOURS_TYPE_ONE = 139;
const REWARDS_ONE_HOURS_TYPE_TWO = 174;
const REWARDS_ONE_HOURS_TYPE_THREE = 232;
const SECONDS_IN_HOUR = 3600;

async function errException(promise) {
	try {
		await promise;
	} catch (error) {
		return error.reason;
	}
	assert.fail('Expected throw not received');
}

contract('Staking', (accounts) => {
	let stakingInstance;
	let stakingTokenInstance;
	let rewardTokenInstance;
	let latestBlock;
	let newLatestBlock;

	const [owner] = accounts;

	beforeEach(async () => {
		stakingTokenInstance = await TestToken.new('stakingToken', 'STK', { from: owner });
		rewardTokenInstance = await TestToken.new('rewardToken', 'RTK', { from: owner });
		stakingInstance = await Staking.new(stakingTokenInstance.address, rewardTokenInstance.address, { from: owner });
	});

	describe('check staking amount settings', () => {
		it('[FAILED] should not allow staking below the minimum stake amount', async () => {
			await errException(stakingInstance.stake(minStakeInWei - 1, 0), { from: owner });
		});

		it('[FAILED] should not allow staking below the maximum stake amount', async () => {
			await errException(stakingInstance.stake(maxStakeInWei + 1, 0), { from: owner });
		});
	});

	describe('check staking deposited balance', () => {
		beforeEach(async () => {
			await stakingTokenInstance.approve(stakingInstance.address, maxStakeInWei + minStakeInWei, { from: owner });
		});

		it('[SUCCESS] should must be deposited min staking amount in the staking smart contract', async () => {
			await stakingInstance.stake(minStakeInWei, 0, { from: owner });
			const stakingInfo = await stakingInstance.getStakingInfo(owner, 0, { from: owner });
			assert.equal(stakingInfo.staked.toString(), minStakeInWei.toString());
			assert.equal(stakingInfo.rewards.toString(), 0);
		});

		it('[SUCCESS] should must be deposited max staking amount in the staking smart contract', async () => {
			await stakingInstance.stake(maxStakeInWei, 0, { from: owner });
			const stakingInfo = await stakingInstance.getStakingInfo(owner, 0, { from: owner });
			assert.equal(stakingInfo.staked.toString(), maxStakeInWei.toString());
			assert.equal(stakingInfo.rewards.toString(), 0);
		});
	});

	describe('check unstaking deposited balance', () => {
		beforeEach(async () => {
			latestBlock = await web3.eth.getBlock('latest');
			await stakingTokenInstance.approve(stakingInstance.address, maxStakeInWei, { from: owner });
			await stakingInstance.stake(maxStakeInWei, 0, { from: owner });
			await timeTraveler.advanceBlockAndSetTime(latestBlock.timestamp + SECONDS_IN_HOUR);
			await timeTraveler.advanceBlock();
		});

		it('[SUCCESS] should must be withdraw unstaking some of amount in the staker address', async () => {
			await stakingInstance.unstake(minStakeInWei, 0, { from: owner });
			const stakingInfo = await stakingInstance.getStakingInfo(owner, 0, { from: owner });
			assert.equal(stakingInfo.staked.toString(), unStakeInWei.toString());
		});

		it('[SUCCESS] should must be withdraw all staking amount in the staking smart contract', async () => {
			await stakingInstance.unstakeAll(0, { from: owner });
			const stakingInfo = await stakingInstance.getStakingInfo(owner, 0, { from: owner });
			assert.equal(stakingInfo.staked.toString(), 0);
		});
	});

	describe('check staking after 1hour token rewards', () => {
		beforeEach(async () => {
			await stakingTokenInstance.approve(stakingInstance.address, maxStakeInWei, { from: owner });
			await stakingInstance.stake(maxStakeInWei, 0, { from: owner });
			await stakingTokenInstance.approve(stakingInstance.address, maxStakeInWei, { from: owner });
			await stakingInstance.stake(maxStakeInWei, 1, { from: owner });
			await stakingTokenInstance.approve(stakingInstance.address, maxStakeInWei, { from: owner });
			await stakingInstance.stake(maxStakeInWei, 2, { from: owner });

			await rewardTokenInstance.transfer(stakingInstance.address, maxStakeInWei, { from: owner });

			latestBlock = await web3.eth.getBlock('latest');

			await timeTraveler.advanceBlockAndSetTime(latestBlock.timestamp + SECONDS_IN_HOUR);
			await timeTraveler.advanceBlock();

			newLatestBlock = await web3.eth.getBlock('latest');
		});

		it('[SUCCESS] should must be increases last block timestamp by 1 hour', async () => {
			const stakingTime = await stakingInstance.getStakingTime(owner, 0, { from: owner });

			// ! Since it is not actually taken from the system's clock, even if the value is set to 3600, there may be some error in practice.
			assert.isTrue(3599 <= newLatestBlock.timestamp - latestBlock.timestampz <= 3601);
			assert.isTrue(3599 <= stakingTime <= 3601);
		});

		it('[SUCCESS] should must be increases last block timestamp by 1 hour', async () => {
			const typeOneRewards = await stakingInstance.calculateRewards(owner, 0, { from: owner });
			const typeTwoRewards = await stakingInstance.calculateRewards(owner, 1, { from: owner });
			const typeThreeRewards = await stakingInstance.calculateRewards(owner, 2, { from: owner });

			// ! Since it is not actually taken from the system's clock, even if the value is set to 3600, there may be some error in practice.
			assert.isTrue(REWARDS_ONE_HOURS_TYPE_ONE - 1 < typeOneRewards / 1e18 <= REWARDS_ONE_HOURS_TYPE_ONE);
			assert.isTrue(REWARDS_ONE_HOURS_TYPE_TWO - 1 < typeTwoRewards / 1e18 <= REWARDS_ONE_HOURS_TYPE_TWO);
			assert.isTrue(REWARDS_ONE_HOURS_TYPE_THREE - 1 < typeThreeRewards / 1e18 <= REWARDS_ONE_HOURS_TYPE_THREE);
		});
	});
});
