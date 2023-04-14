const Staking_Contract = artifacts.require('Staking');
const TestToken_Contract = artifacts.require('TestToken');

module.exports = async (deployer) => {
	await deployer.deploy(TestToken_Contract, 'StakingToken', 'STK');

	const stakingTokenInstance = await TestToken_Contract.deployed();

	await deployer.deploy(TestToken_Contract, 'RewardToken', 'RTK');

	const rewardTokenInstance = await TestToken_Contract.deployed();

	deployer.deploy(Staking_Contract, stakingTokenInstance.address, rewardTokenInstance.address);
};
