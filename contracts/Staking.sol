// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract Staking is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    /**
     * @notice 스테이킹 토큰
     * @dev immutable 타입으로 수정 불가능합니다.
     */
    IERC20 public immutable stakingToken;
    
    /**
     * @notice 리워드 토큰
     * @dev immutable 타입으로 수정 불가능합니다.
     */
    IERC20 public immutable rewardsToken;

    /**
     * @notice 최소 스테이킹 금액
     */
    uint256 public minStake = 1000 ether;

    /**
     * @notice 최대 스테이킹 금액
     */
    uint256 public maxStake = 1000000 ether;

    /**
     * @notice 스테이킹 타입 열거형
     * @dev 스테이킹 타입으로 각각의 스테이킹 기간과 보상률이 다릅니다.
     */
    enum StakingType {THIRTY , SIXTY , NINETY}

    /**
     * @notice 예치일 기준 구조체
     */
    struct StakingPeriod {
        uint24 periodsOne;
        uint24 periodsTwo;
        uint24 periodsThree;
    }

    /**
     * @notice 보상률 구조체
     */
    struct ReturnRate {
        uint16 rateOne;
        uint16 rateTwo;
        uint16 rateThree;
    }

    /**
     * @notice 스테이킹 예치일 기준 구조체로 각각 30일, 60일, 90일을 의미합니다.
     */
    StakingPeriod public stakingPeriods = StakingPeriod({
        periodsOne : 30 days,
        periodsTwo : 60 days,
        periodsThree : 90 days
    });
    
    /**
     * @notice 보상률 구조체로 각각 시간당 0.0139%, 0.0174%, 0.0232%를 의미합니다.
     */
    ReturnRate public returnRate = ReturnRate({
        rateOne: 1390, // 30일간 약 10%
        rateTwo: 1740, // 60일간 약 25%
        rateThree: 2320 // 90일간 약 50%
    });

    /**
     * @notice 스테이킹 현황 구조체
     */
    struct StakingInfo {
        uint256 deposited;
        uint256 firstAt;
        uint256 updateAt;
        uint256 rewards;
    }

    uint16 constant hourInSeconds = 3600;

    /**
     * @notice 스테이커 매핑
     */
    mapping(address => StakingInfo[3]) internal stakers;

    /**
     * @notice 생성자 함수
     * @param _stakingToken - 스테이킹 토큰
     * @param _rewardToken - 보상 토큰
     */
    constructor(address _stakingToken, address _rewardToken) {
        stakingToken = IERC20(_stakingToken);
        rewardsToken = IERC20(_rewardToken);  
    }

    /**
     * @notice 스테이커가 토큰을 스테이킹에 예치합니다.
     * @param _amount - 에치 금액
     * @param _type - 스테이킹 타입
     * @dev 스테이커는 _type에 따라 30, 60, 90일 동안 예치하여 보상을 받을 수 있습니다. nonReentrant를 사용하여 재진입 공격을 방지합니다.
     * 기존에 진행중인 스테이킹이 있다면 최대 스테이킹 금액 내에서 추가 스테이킹을 하고, 
     * 스테이킹을 완료하고 다시 스테이킹을 시도할 경우 남아있는 미지급 보상이 있다면 되돌리고 보상을 모두 받았다면 스테이킹 내용을 초기화하여 다시 스테이킹을 진행합니다.
     */
    function stake(uint256 _amount, StakingType _type) external nonReentrant {
        require(_amount >= minStake, "Staking : Deposit amount smaller than minimimum deposit amount");
        require(_amount <= maxStake, "Staking : Deposit amount bigger than maximum deposit amount");
        StakingInfo storage staker = stakers[msg.sender][uint256(_type)];
        uint256 periods = uint256(_type) == 0 ? stakingPeriods.periodsOne : uint256(_type) == 1 ?  stakingPeriods.periodsTwo : stakingPeriods.periodsThree;
        if(staker.deposited == 0){
            staker.rewards = 0;
            staker.deposited = _amount;
            staker.firstAt = block.timestamp;
        } else {
            updateReward(msg.sender, _type);
            if(block.timestamp > staker.firstAt + periods){
                require(staker.rewards <= 0,"Staking : Receive your reward and try staking again");
                staker.rewards = 0;
                staker.deposited = _amount;
                staker.firstAt = block.timestamp;
            } else {
                require(_amount <= maxStake - staker.deposited, "Staking : Total deposit amount bigger than maximum deposit amount");
                staker.deposited.add( _amount);
            }
        }
        staker.updateAt = block.timestamp;
        stakingToken.transferFrom(msg.sender, address(this), _amount);
    }

    /**
     * @notice 사용자가 예치한 토큰 일부를 회수할 때 사용합니다.
     * @param _amount - 회수 금액
     * @param _type - 스테이킹 타입
     * @dev 스테이커의 미지급 보상을 최신화하고 예치한 토큰을 일부 회수합니다. nonReentrant를 사용하여 재진입 공격을 방지합니다.
     */
    function unstake(uint256 _amount, StakingType _type) external nonReentrant {
        StakingInfo storage staker = stakers[msg.sender][uint256(_type)];
        require(staker.deposited > 0, "Staking : You did not stake");
        require(staker.deposited >= _amount, "Staking : Insufficient amount staked");
        updateReward(msg.sender, _type);
        staker.deposited -= _amount;
        staker.updateAt = block.timestamp;
        stakingToken.transfer(msg.sender, _amount);
    }

    /**
     * @notice 사용자가 예치한 토큰 전액을 회수할 때 사용합니다.
     * @param _type - 스테이킹 타입
     * @dev 스테이커의 미지급 보상을 최신화하고 예치한 토큰을 모두 회수합니다. nonReentrant를 사용하여 재진입 공격을 방지합니다.
     */
    function unstakeAll(StakingType _type) external nonReentrant {
        StakingInfo storage staker = stakers[msg.sender][uint256(_type)];
        require(staker.deposited > 0, "Staking : You did not stake");
        updateReward(msg.sender, _type);
        uint256 _amount = staker.deposited;
        staker.deposited = 0;
        staker.updateAt = block.timestamp;
        stakingToken.transfer(msg.sender, _amount);
    }

    /**
     * @notice 사용자가 현재 보유한 보상을 청구하는데 사용합니다.
     * @param _type - 스테이킹 타입
     * @dev 스테이커의 미지급 보상을 최신화 후 지급하며, 보상을 초기화 합니다. nonReentrant를 사용하여 재진입 공격을 방지합니다.
     */ 
    function claimRewards(StakingType _type) external nonReentrant {
        StakingInfo storage staker = stakers[msg.sender][uint256(_type)];
        require(staker.deposited > 0, "Staking : You did not stake");
        updateReward(msg.sender, _type);
        uint256 rewards = staker.rewards;
        require(rewards > 0, "Staking : You have no rewards");
        staker.rewards = 0;
        staker.updateAt = block.timestamp;
        rewardsToken.transfer(msg.sender, rewards);
    }

    /**
     * @notice 스테이커의 스테이킹 정보를 조회하는데 사용합니다.
     * @param _staker - 스테이커 지갑 주소
     * @param _type - 스테이킹 타입
     * @return staked - 스테이킹 수량
     * @return rewards - 보상 수량
     * @dev 스테이커의 스테이킹 토큰양과 현재 누적 보상을 계산하여 반환합니다.
     */
    function getStakingInfo(address _staker, StakingType _type) public view returns(uint256 staked, uint256 rewards) {
        StakingInfo storage staker = stakers[_staker][uint256(_type)];
        uint256 _staked = staker.deposited;
        uint256 _rewards = staker.rewards;
        return (_staked, _rewards);
    }

    /**
     * @notice 보상 현황 업데이트 함수 변경자
     * @param _staker - 스테이커 지갑 주소
     * @param _type - 스테이킹 타입
     * @dev - 스테이커의 보상을 조회하기전 보상 정보를 최신화합니다.
     */
    function updateReward(address _staker, StakingType _type) internal {
        StakingInfo storage staker = stakers[_staker][uint256(_type)];
        staker.rewards = calculateRewards(_staker, _type).add(staker.rewards);
    }

    /**
     * @notice 스테이커의 보상을 계산하는데 사용합니다.
     * @param _staker - 스테이커 지갑 주소
     * @param _type - 스테이킹 타입
     * @return rewards - 보상 수량
     * @dev 보상 계산식 : 스테이킹 총 수량 * 시간당 수익률 / 10000000 *  ( 마지막 블록 생성 시간 - 마지막 업데이트 시간 ) / 1시간 timestamp
     * 스테이킹 시간을 계산할 때 마지막 블록 생성 시간과 최초 스테이킹 시간 + 예치일 시간을 비교하여 예치일이 지났는지 안지났는지 확인하고 더 작은 값을 가져와 마지막 업데이트 시간을 빼서 총 스테이킹 시간을 구합니다.
     * 마지막 블록 생성 시간이 더 작을 경우 == 스테이킹 진행중 / 최초 스테이킹 시간 + 예치일 시간이 더 작을 경우 == 스테이킹 종료
     */
    function calculateRewards(address _staker, StakingType _type) public view returns(uint256 rewards) {
        StakingInfo storage staker = stakers[_staker][uint256(_type)];
        uint256 stakingType = uint256(_type);
        uint256 periods = stakingType == 0 ? stakingPeriods.periodsOne : stakingType == 1 ?  stakingPeriods.periodsTwo : stakingPeriods.periodsThree;
        uint256 rate = stakingType == 0 ? returnRate.rateOne : stakingType == 1 ?  returnRate.rateTwo : returnRate.rateThree;
        uint256 stakingTime = Math.min(block.timestamp, staker.firstAt + periods).sub(staker.updateAt);
        require(stakingTime > 0, "Staking : You have no stakingTime");
        uint256 _rewards = staker.deposited.mul(rate).div(10000000).mul(stakingTime).div(hourInSeconds);
        return _rewards;
    }

    /**
     * @notice 스테이킹 시간을 조회합니다.
     * @param _staker - 스테이커 지갑 주소
     * @param _type - 스테이킹 타입
     * @return stakingTime - 스테이킹 시간 timestamp
     * @dev 마지막 블록 생성 시간 - 마지막 스테이킹 정보 업데이트 시간
     */
    function getStakingTime(address _staker, StakingType _type) public view returns(uint256 stakingTime){
        return block.timestamp.sub(stakers[_staker][uint256(_type)].updateAt);
    }
}