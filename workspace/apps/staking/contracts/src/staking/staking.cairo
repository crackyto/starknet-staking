#[starknet::contract]
pub mod Staking {
    use core::option::OptionTrait;
    use core::num::traits::zero::Zero;
    use contracts::{
        BASE_VALUE, errors::{Error, panic_by_err, assert_with_err, expect_with_err},
        staking::{IStaking, StakerInfo, StakingContractInfo}, utils::{u128_mul_wide_and_div_unsafe},
    };
    use starknet::{ContractAddress, get_contract_address, get_caller_address};
    use openzeppelin::{
        access::accesscontrol::AccessControlComponent, introspection::src5::SRC5Component
    };
    use contracts_commons::custom_defaults::{ContractAddressDefault, OptionDefault};
    use openzeppelin::token::erc20::interface::{IERC20DispatcherTrait, IERC20Dispatcher};
    use starknet::get_block_timestamp;

    // TODO: Decide if MIN_INCREASE_STAKE is needed (if needed then decide on a value). 
    pub const MIN_INCREASE_STAKE: u128 = 10;
    pub const REV_SHARE_DENOMINATOR: u8 = 100;
    pub const EXIT_WAITING_WINDOW: u64 = 60 * 60 * 24 * 7 * 3; // 3 weeks

    component!(path: AccessControlComponent, storage: accesscontrol, event: accesscontrolEvent);
    component!(path: SRC5Component, storage: src5, event: src5Event);

    #[abi(embed_v0)]
    impl AccessControlImpl =
        AccessControlComponent::AccessControlImpl<ContractState>;

    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        accesscontrol: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        global_index: u64,
        min_stake: u128,
        staker_info: LegacyMap::<ContractAddress, StakerInfo>,
        operational_address_to_staker_address: LegacyMap::<ContractAddress, ContractAddress>,
        max_leverage: u64,
        token_address: ContractAddress,
        total_stake: u128,
    }

    #[derive(Drop, starknet::Event)]
    struct BalanceChanged {
        staker_address: ContractAddress,
        amount: u128
    }

    #[derive(Drop, starknet::Event)]
    struct NewPool {
        staker_address: ContractAddress,
        pooling_contract_address: ContractAddress
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        accesscontrolEvent: AccessControlComponent::Event,
        src5Event: SRC5Component::Event,
    }

    #[constructor]
    pub fn constructor(
        ref self: ContractState, token_address: ContractAddress, min_stake: u128, max_leverage: u64
    ) {
        self.token_address.write(token_address);
        self.min_stake.write(min_stake);
        self.max_leverage.write(max_leverage);
        self.global_index.write(BASE_VALUE);
    }

    #[abi(embed_v0)]
    impl StakingImpl of IStaking<ContractState> {
        fn stake(
            ref self: ContractState,
            reward_address: ContractAddress,
            operational_address: ContractAddress,
            amount: u128,
            pooling_enabled: bool,
            rev_share: u8,
        ) -> bool {
            let staker_address = get_caller_address();
            assert_with_err(
                self.staker_info.read(staker_address).amount_own.is_zero(), Error::STAKER_EXISTS
            );
            assert_with_err(
                self.operational_address_to_staker_address.read(operational_address).is_zero(),
                Error::OPERATIONAL_EXISTS
            );
            assert_with_err(amount >= self.min_stake.read(), Error::AMOUNT_LESS_THAN_MIN_STAKE);
            assert_with_err(rev_share <= REV_SHARE_DENOMINATOR, Error::REV_SHARE_OUT_OF_RANGE);
            let staking_contract_address = get_contract_address();
            let erc20_dispatcher = IERC20Dispatcher { contract_address: self.token_address.read() };
            erc20_dispatcher
                .transfer_from(
                    sender: staker_address,
                    recipient: staking_contract_address,
                    amount: amount.into()
                );
            // TODO(Nir, 01/08/2024): Deploy pooling contract if pooling_enabled is true.
            if pooling_enabled {}
            self
                .staker_info
                .write(
                    staker_address,
                    StakerInfo {
                        reward_address: reward_address,
                        operational_address: operational_address,
                        pooling_contract: Option::None,
                        unstake_time: Option::None,
                        amount_own: amount,
                        amount_pool: 0,
                        index: self.global_index.read(),
                        unclaimed_rewards_own: 0,
                        unclaimed_rewards_pool: 0,
                        rev_share: rev_share,
                    }
                );
            self.operational_address_to_staker_address.write(operational_address, staker_address);
            self.total_stake.write(self.get_total_stake() + amount);
            true
        }

        fn increase_stake(
            ref self: ContractState, staker_address: ContractAddress, amount: u128
        ) -> u128 {
            let mut staker_info = self.staker_info.read(staker_address);
            assert_with_err(staker_info.amount_own.is_non_zero(), Error::STAKER_NOT_EXISTS);
            assert_with_err(staker_info.unstake_time.is_none(), Error::UNSTAKE_IN_PROGRESS);
            assert_with_err(
                amount >= MIN_INCREASE_STAKE, Error::AMOUNT_LESS_THAN_MIN_INCREASE_STAKE
            );
            let caller_address = get_caller_address();
            assert_with_err(
                caller_address == staker_address || caller_address == staker_info.reward_address,
                Error::CALLER_CANNOT_INCREASE_STAKE
            );
            let staking_contract_address = get_contract_address();
            let erc20_dispatcher = IERC20Dispatcher { contract_address: self.token_address.read() };
            erc20_dispatcher
                .transfer_from(
                    sender: caller_address,
                    recipient: staking_contract_address,
                    amount: amount.into()
                );
            self.calculate_rewards(staker_address, ref staker_info);
            staker_info.amount_own += amount;
            self.staker_info.write(staker_address, staker_info);
            self.total_stake.write(self.get_total_stake() + amount);
            staker_info.amount_own
        }

        fn claim_rewards(ref self: ContractState, staker_address: ContractAddress) -> u128 {
            let mut staker_info = self.staker_info.read(staker_address);
            // Reward address isn't zero if staker is initialized.
            assert_with_err(staker_info.amount_own.is_non_zero(), Error::STAKER_NOT_EXISTS);
            let caller_address = get_caller_address();
            assert_with_err(
                caller_address == staker_address || caller_address == staker_info.reward_address,
                Error::CLAIM_REWARDS_FROM_UNAUTHORIZED_ADDRESS
            );
            self.calculate_rewards(staker_address, ref staker_info);
            let amount = staker_info.unclaimed_rewards_own;

            let erc20_dispatcher = IERC20Dispatcher { contract_address: self.token_address.read() };
            erc20_dispatcher.transfer(recipient: staker_info.reward_address, amount: amount.into());

            staker_info.unclaimed_rewards_own = 0;
            self.staker_info.write(staker_address, staker_info);
            amount
        }

        fn unstake_intent(ref self: ContractState) -> u64 {
            let staker_address = get_caller_address();
            let mut staker_info = self.staker_info.read(staker_address);
            assert_with_err(staker_info.amount_own.is_non_zero(), Error::STAKER_NOT_EXISTS);
            assert_with_err(staker_info.unstake_time.is_none(), Error::UNSTAKE_IN_PROGRESS);
            self.calculate_rewards(staker_address, ref :staker_info);
            let current_time = get_block_timestamp();
            let unstake_time = current_time + EXIT_WAITING_WINDOW;
            staker_info.unstake_time = Option::Some(unstake_time);
            self.staker_info.write(staker_address, staker_info);
            unstake_time
        }

        fn unstake_action(ref self: ContractState, staker_address: ContractAddress) -> u128 {
            0
        }

        fn add_to_delegation_pool(
            ref self: ContractState, pooled_staker: ContractAddress, amount: u128
        ) -> (u128, u64) {
            (0, self.global_index.read())
        }

        fn remove_from_delegation_pool_intent(
            ref self: ContractState,
            staker_address: ContractAddress,
            amount: u128,
            identifier: Span<felt252>
        ) -> felt252 {
            0
        }

        fn remove_from_delegation_pool_action(
            ref self: ContractState, staker_address: ContractAddress, identifier: Span<felt252>
        ) -> u128 {
            0
        }

        fn switch_staking_delegation_pool(
            ref self: ContractState,
            from_staker_address: ContractAddress,
            to_staker_address: ContractAddress,
            to_pool_address: ContractAddress,
            amount: u128,
            data: Span<felt252>
        ) -> bool {
            true
        }

        fn change_reward_address(ref self: ContractState, reward_address: ContractAddress) -> bool {
            let staker_address = get_caller_address();
            assert_with_err(
                self.staker_info.read(staker_address).amount_own.is_non_zero(),
                Error::STAKER_NOT_EXISTS
            );

            let mut staker_info = self.staker_info.read(staker_address);
            staker_info.reward_address = reward_address;
            self.staker_info.write(staker_address, staker_info);
            true
        }

        fn set_open_for_delegation(ref self: ContractState) -> ContractAddress {
            Default::default()
        }

        fn state_of(self: @ContractState, staker_address: ContractAddress) -> StakerInfo {
            let staker_info = self.get_staker(staker_address);
            expect_with_err(staker_info, Error::STAKER_NOT_EXISTS)
        }

        fn contract_parameters(self: @ContractState) -> StakingContractInfo {
            StakingContractInfo {
                min_stake: self.min_stake.read(),
                max_leverage: self.max_leverage.read(),
                token_address: self.token_address.read(),
                global_index: self.global_index.read(),
            }
        }

        fn claim_delegation_pool_rewards(
            ref self: ContractState, staker_address: ContractAddress
        ) -> u64 {
            let mut staker_info = self.staker_info.read(staker_address);
            // Reward address isn't zero if staker is initialized.
            assert_with_err(staker_info.amount_own.is_non_zero(), Error::STAKER_NOT_EXISTS);
            let pool_address = expect_with_err(
                staker_info.pooling_contract, Error::POOL_ADDRESS_DOES_NOT_EXIST
            );
            assert_with_err(
                pool_address == get_caller_address(),
                Error::CLAIM_DELEGATION_POOL_REWARDS_FROM_UNAUTHORIZED_ADDRESS
            );
            self.calculate_rewards(staker_address, ref staker_info);
            // Calculate rewards updated the index in staker_info.
            let updated_index = staker_info.index;
            let erc20_dispatcher = IERC20Dispatcher { contract_address: self.token_address.read() };
            erc20_dispatcher
                .transfer(
                    recipient: pool_address, amount: staker_info.unclaimed_rewards_pool.into()
                );

            staker_info.unclaimed_rewards_pool = 0;
            self.staker_info.write(staker_address, staker_info);
            updated_index
        }

        fn get_total_stake(self: @ContractState) -> u128 {
            self.total_stake.read()
        }
    }

    #[generate_trait]
    pub impl InternalStakingFunctions of InternalStakingFunctionsTrait {
        fn get_staker(self: @ContractState, staker_address: ContractAddress) -> Option<StakerInfo> {
            let staker_info = self.staker_info.read(staker_address);
            // Reward address isn't zero if staker is initialized.
            if staker_info.amount_own.is_zero() {
                Option::None
            } else {
                Option::Some(staker_info)
            }
        }

        /// Calculates the rewards for a given staker.
        /// 
        /// The caller for this function should validate that the staker exists in the storage
        /// 
        /// rewards formula:
        /// $$ interest = (global\_index-self\_index) $$
        /// 
        /// single staker:
        /// $$ rewards = staker\_amount\_own * interest $$
        /// 
        /// staker with pool:
        /// $$ rewards = staker\_amount\_own * interest + staker\_amount\_pool * interest * global\_rev\_share $$
        fn calculate_rewards(
            ref self: ContractState, staker_address: ContractAddress, ref staker_info: StakerInfo
        ) -> bool {
            if (staker_info.unstake_time.is_some()) {
                return false;
            }
            let global_index = self.global_index.read();
            let interest: u64 = global_index - staker_info.index;
            let mut own_rewards = u128_mul_wide_and_div_unsafe(
                staker_info.amount_own, interest.into(), BASE_VALUE.into(), Error::REWARDS_ISNT_U128
            );
            if (staker_info.pooling_contract.is_some()) {
                // todo: see if we can do without the special mul
                let mut pooled_rewards = u128_mul_wide_and_div_unsafe(
                    staker_info.amount_pool,
                    interest.into(),
                    BASE_VALUE.into(),
                    Error::POOLED_REWARDS_ISNT_U128
                );
                let rev_share = u128_mul_wide_and_div_unsafe(
                    pooled_rewards,
                    staker_info.rev_share.into(),
                    REV_SHARE_DENOMINATOR.into(),
                    Error::REV_SHARE_ISNT_U128
                );
                own_rewards += rev_share;
                pooled_rewards -= rev_share;
                staker_info.unclaimed_rewards_pool += pooled_rewards;
            }
            staker_info.unclaimed_rewards_own += own_rewards;
            staker_info.index = global_index;
            self.staker_info.write(staker_address, staker_info);
            true
        }
    }
}
