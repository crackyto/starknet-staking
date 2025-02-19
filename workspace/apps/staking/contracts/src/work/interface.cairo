use starknet::ContractAddress;

#[starknet::interface]
pub trait IWork<TContractState> {
    fn work(ref self: TContractState, work_info: WorkInfo);
    // TODO: Rename address to staker_address or operational_address when it known.
    fn is_work_done_in_curr_epoch(self: @TContractState, address: ContractAddress) -> bool;
}

// TODO: implement
pub mod Events {}

// TODO: implement
#[derive(Debug, Copy, Drop, Serde, PartialEq)]
pub struct WorkInfo {}
