use contracts_commons::errors::{Describable, ErrorDisplay};
use staking::constants::MAX_C_NUM;
use staking::staking::staking::Staking::COMMISSION_DENOMINATOR;

#[derive(Drop)]
pub(crate) enum Error {
    // Generic errors
    MESSAGES_COUNT_ISNT_U32,
    INTEREST_ISNT_INDEX_TYPE,
    REWARDS_ISNT_AMOUNT_TYPE,
    BALANCE_ISNT_AMOUNT_TYPE,
    COMMISSION_ISNT_AMOUNT_TYPE,
    // ERC20 errors,
    INSUFFICIENT_BALANCE,
    INSUFFICIENT_ALLOWANCE,
    // Shared errors
    STAKER_EXISTS,
    STAKER_NOT_EXISTS,
    OPERATIONAL_EXISTS,
    CALLER_CANNOT_INCREASE_STAKE,
    INVALID_REWARD_ADDRESS,
    INTENT_WINDOW_NOT_FINISHED,
    AMOUNT_TOO_HIGH,
    AMOUNT_IS_ZERO,
    INVALID_COMMISSION,
    // Staking contract errors
    AMOUNT_LESS_THAN_MIN_STAKE,
    COMMISSION_OUT_OF_RANGE,
    UNSTAKE_IN_PROGRESS,
    POOL_ADDRESS_DOES_NOT_EXIST,
    CLAIM_REWARDS_FROM_UNAUTHORIZED_ADDRESS,
    MISSING_UNSTAKE_INTENT,
    CALLER_IS_NOT_POOL_CONTRACT,
    MISSING_POOL_CONTRACT,
    DELEGATION_POOL_MISMATCH,
    GLOBAL_INDEX_DIFF_NOT_INDEX_TYPE,
    GLOBAL_INDEX_DIFF_COMPUTATION_OVERFLOW,
    UNEXPECTED_BALANCE,
    STAKER_ALREADY_HAS_POOL,
    CONTRACT_IS_PAUSED,
    INVALID_UNDELEGATE_INTENT_VALUE,
    OPERATIONAL_NOT_ELIGIBLE,
    OPERATIONAL_IN_USE,
    CALLER_IS_ZERO_ADDRESS,
    SELF_SWITCH_NOT_ALLOWED,
    ILLEGAL_EXIT_DURATION,
    // Pool contract errors
    POOL_MEMBER_DOES_NOT_EXIST,
    STAKER_INACTIVE,
    POOL_MEMBER_EXISTS,
    UNDELEGATE_IN_PROGRESS,
    INSUFFICIENT_POOL_BALANCE,
    CALLER_IS_NOT_STAKING_CONTRACT,
    SWITCH_POOL_DATA_DESERIALIZATION_FAILED,
    FINAL_STAKER_INDEX_ALREADY_SET,
    MISSING_UNDELEGATE_INTENT,
    CALLER_CANNOT_ADD_TO_POOL,
    REWARD_ADDRESS_MISMATCH,
    // Minting contract errors
    TOTAL_SUPPLY_NOT_AMOUNT_TYPE,
    POOL_CLAIM_REWARDS_FROM_UNAUTHORIZED_ADDRESS,
    UNAUTHORIZED_MESSAGE_SENDER,
    C_NUM_OUT_OF_RANGE,
    // Reward Supplier contract errors
    ON_RECEIVE_NOT_FROM_STARKGATE,
    UNEXPECTED_TOKEN,
}

impl DescribableError of Describable<Error> {
    #[inline(always)]
    fn describe(self: @Error) -> ByteArray {
        match self {
            Error::ON_RECEIVE_NOT_FROM_STARKGATE => "Only StarkGate can call on_receive",
            Error::MESSAGES_COUNT_ISNT_U32 => "Number of messages is too large, expected to fit in u32",
            Error::INTEREST_ISNT_INDEX_TYPE => "Interest is too large, expected to fit in u128",
            Error::REWARDS_ISNT_AMOUNT_TYPE => "Rewards is too large, expected to fit in u128",
            Error::BALANCE_ISNT_AMOUNT_TYPE => "Balance is too large, expected to fit in u128",
            Error::COMMISSION_ISNT_AMOUNT_TYPE => "Commission is too large, expected to fit in u128",
            Error::STAKER_EXISTS => "Staker already exists, use increase_stake instead",
            Error::STAKER_NOT_EXISTS => "Staker does not exist",
            Error::CALLER_CANNOT_INCREASE_STAKE => "Caller address should be staker address or reward address",
            Error::INVALID_REWARD_ADDRESS => "Invalid reward address",
            Error::AMOUNT_TOO_HIGH => "Amount is too high",
            Error::AMOUNT_IS_ZERO => "Amount is zero",
            Error::INTENT_WINDOW_NOT_FINISHED => "Intent window is not finished",
            Error::OPERATIONAL_EXISTS => "Operational address already exists",
            Error::OPERATIONAL_NOT_ELIGIBLE => "Operational address had not been declared by staker",
            Error::OPERATIONAL_IN_USE => "Operational address is in use",
            Error::AMOUNT_LESS_THAN_MIN_STAKE => "Amount is less than min stake - try again with enough funds",
            Error::COMMISSION_OUT_OF_RANGE => format!(
                "Commission is out of range, expected to be 0-{}", COMMISSION_DENOMINATOR,
            ),
            Error::POOL_ADDRESS_DOES_NOT_EXIST => "Pool address does not exist",
            Error::MISSING_UNSTAKE_INTENT => "Unstake intent is missing",
            Error::UNSTAKE_IN_PROGRESS => "Unstake is in progress, staker is in an exit window",
            Error::CLAIM_REWARDS_FROM_UNAUTHORIZED_ADDRESS => "Claim rewards must be called from staker address or reward address",
            Error::POOL_MEMBER_DOES_NOT_EXIST => "Pool member does not exist",
            Error::STAKER_INACTIVE => "Staker inactive",
            Error::POOL_MEMBER_EXISTS => "Pool member exists, use add_to_delegation_pool instead",
            Error::UNDELEGATE_IN_PROGRESS => "Undelegate from pool in progress, pool member is in an exit window",
            Error::INSUFFICIENT_POOL_BALANCE => "Insufficient pool balance",
            Error::TOTAL_SUPPLY_NOT_AMOUNT_TYPE => "Total supply does not fit in u128",
            Error::POOL_CLAIM_REWARDS_FROM_UNAUTHORIZED_ADDRESS => "Claim rewards must be called from pool member address or reward address",
            Error::CALLER_IS_NOT_POOL_CONTRACT => "Caller is not pool contract",
            Error::CALLER_IS_NOT_STAKING_CONTRACT => "Caller is not staking contract",
            Error::FINAL_STAKER_INDEX_ALREADY_SET => "Final staker index already set",
            Error::MISSING_UNDELEGATE_INTENT => "Undelegate intent is missing",
            Error::CALLER_CANNOT_ADD_TO_POOL => "Caller address should be pool member address or reward address",
            Error::REWARD_ADDRESS_MISMATCH => "Reward address mismatch",
            Error::MISSING_POOL_CONTRACT => "Staker does not have a pool contract",
            Error::UNAUTHORIZED_MESSAGE_SENDER => "Unauthorized message sender",
            Error::SWITCH_POOL_DATA_DESERIALIZATION_FAILED => "Switch pool data deserialization failed",
            Error::DELEGATION_POOL_MISMATCH => "to_pool is not the delegation pool contract for to_staker",
            Error::GLOBAL_INDEX_DIFF_NOT_INDEX_TYPE => "Global index diff does not fit in u128",
            Error::GLOBAL_INDEX_DIFF_COMPUTATION_OVERFLOW => "Overflow during computation global index diff",
            Error::UNEXPECTED_BALANCE => "Unexpected balance",
            Error::INVALID_COMMISSION => "Commission can only be decreased",
            Error::STAKER_ALREADY_HAS_POOL => "Staker already has a pool",
            Error::CONTRACT_IS_PAUSED => "Contract is paused",
            Error::C_NUM_OUT_OF_RANGE => format!("C Numerator out of range (0-{})", MAX_C_NUM),
            Error::INSUFFICIENT_BALANCE => "Insufficient ERC20 balance",
            Error::INSUFFICIENT_ALLOWANCE => "Insufficient ERC20 allowance",
            Error::INVALID_UNDELEGATE_INTENT_VALUE => "Invalid undelegate intent value",
            Error::UNEXPECTED_TOKEN => "UNEXPECTED_TOKEN",
            Error::CALLER_IS_ZERO_ADDRESS => "Zero address caller is not allowed",
            Error::SELF_SWITCH_NOT_ALLOWED => "SELF_SWITCH_NOT_ALLOWED",
            Error::ILLEGAL_EXIT_DURATION => "ILLEGAL_EXIT_DURATION",
        }
    }
}

