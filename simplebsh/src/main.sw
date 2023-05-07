contract;

use signed_integers::i256::I256;
use std::{
    u256::U256,
    block::height
};
use yama_interfaces::{
    simplebsh_abi::SimpleBSH,
    errors::SimpleBSHError
};
use stablecoin_library::{
    helpers::{
        verify_sender_allowed,
        total_surplus,
        mint,
        add_deficit,
        u64_to_i256,
        i256_to_u64
    },
    constants::{
        ZERO_B256,
        SBSH_REVENUE_SHARE,
        SBSH_DENOMINATOR
    },
};

use std::{
    auth::caller_contract_id
};

storage {
    stablecoin_contract: b256 = ZERO_B256,
    balancesheet_module: b256 = ZERO_B256,
    target: b256 = ZERO_B256,
    revenue_share: u64 = SBSH_REVENUE_SHARE,
    pending_share_amount: I256 = I256::new(),
    last_block_update: u64 = 0,
}

impl SimpleBSH for Contract {
    #[storage(read, write)]
    fn on_add_surplus(amount: I256) {
        require(
            caller_contract_id().value == storage.balancesheet_module,
            SimpleBSHError::NotBalanceSheet
        );
        let share_amount = (
            amount * u64_to_i256(storage.revenue_share)
            / u64_to_i256(SBSH_DENOMINATOR));
        if share_amount > u64_to_i256(0) {
            storage.pending_share_amount += share_amount;
            mint(
                i256_to_u64(share_amount),
                Identity::ContractId(ContractId {value: storage.target}),
                storage.stablecoin_contract
            );
            add_deficit(
                share_amount,
                storage.balancesheet_module
            );
        }
    }

    #[storage(read, write)]
    fn on_add_deficit(amount: I256) {}

    #[storage(read, write)]
    fn get_revenue_share() -> u64 {
        storage.revenue_share
    }

    #[storage(read, write)]
    fn process_pending_share_amount() {
        process_pending_share_amount();
    }

    #[storage(read, write)]
    fn set_revenue_share(amount: u64) {
        verify_sender_allowed(storage.stablecoin_contract);
        require(
            amount <= SBSH_DENOMINATOR,
            SimpleBSHError::RevenueShareExceedsDenominator
        );
        storage.revenue_share = amount;
    }

    #[storage(read, write)]
    fn set_balancesheet_module(value: b256) {
        verify_sender_allowed(storage.stablecoin_contract);
        storage.balancesheet_module = value;
    }

    #[storage(read)]
    fn get_stablecoin_contract() -> b256 {
        storage.stablecoin_contract
    }

    #[storage(read)]
    fn get_balancesheet_module() -> b256 {
        storage.balancesheet_module
    }

    #[storage(read)]
    fn get_target() -> b256 {
        storage.target
    }

    #[storage(read)]
    fn get_pending_share_amount() -> I256 {
        storage.pending_share_amount
    }

    #[storage(read)]
    fn get_last_block_update() -> u64 {
        storage.last_block_update
    }
}

#[storage(read, write)]
fn process_pending_share_amount() {
    if (height() > storage.last_block_update) {
        if storage.pending_share_amount > u64_to_i256(0) {
            mint(
                i256_to_u64(storage.pending_share_amount),
                Identity::ContractId(ContractId {value: storage.target}),
                storage.stablecoin_contract
            );
            storage.pending_share_amount = u64_to_i256(0);
        }
        storage.last_block_update = height();
    }
}