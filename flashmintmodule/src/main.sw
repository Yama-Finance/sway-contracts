contract;

use yama_interfaces::{
    flashmintmodule_abi::FlashMintModule,
    flashmintborrower_abi::FlashMintBorrower,
    errors::FlashMintModuleError
};
use stablecoin_library::{
    helpers::{
        verify_sender_allowed,
        verify_tokens_from,
        mint,
        burn,
        sender_id
    },
    constants::{
        ZERO_B256,
        FMM_MAX
    }
};
use std::{
    auth::caller_contract_id,
    context::msg_amount,
    storage::StorageVec,
    bytes::Bytes
};

storage {
    stablecoin_contract: b256 = ZERO_B256,
    max: u64 = FMM_MAX,
    flash_loan_amount: StorageVec<u64> = StorageVec{},
    flash_loan_sender: StorageVec<ContractId> = StorageVec{},
}

impl FlashMintModule for Contract {
    #[storage(read, write)]
    fn flash_loan(
        amount: u64,
        calldata: Vec<u8>
    ) {
        require(amount <= storage.max, FlashMintModuleError::ExceedsMax);
        storage.flash_loan_amount.push(amount);
        storage.flash_loan_sender.push(caller_contract_id());
        mint(amount, sender_id(), storage.stablecoin_contract);

        let borrower = abi(FlashMintBorrower, caller_contract_id().value);
        borrower.flash_loan_callback(sender_id(), amount, calldata);

        let loan_index = storage.flash_loan_amount.len() - 1;
        require(
            storage.flash_loan_amount.get(loan_index).unwrap() == 0,
            FlashMintModuleError::NotRepaid
        );
        storage.flash_loan_amount.pop();
        storage.flash_loan_sender.pop();
    }

    #[payable]
    #[storage(read, write)]
    fn repay() {
        verify_tokens_from(storage.stablecoin_contract);
        let loan_index = storage.flash_loan_amount.len() - 1;
        require(loan_index > 0, FlashMintModuleError::NoLoanToRepay);
        require(
            storage.flash_loan_sender.get(loan_index).unwrap() == caller_contract_id(),
            FlashMintModuleError::InvalidRepaySender
        );
        require(
            storage.flash_loan_amount.get(loan_index).unwrap() >= msg_amount(),
            FlashMintModuleError::RepayOverpayment
        );

        burn(msg_amount(), storage.stablecoin_contract);

        storage.flash_loan_amount.set(
            loan_index,
            storage.flash_loan_amount.get(loan_index).unwrap() - msg_amount()
        );
    }

    #[storage(read)]
    fn get_max() -> u64 {
        storage.max
    }

    #[storage(read, write)]
    fn set_max(amount: u64) {
        verify_sender_allowed(storage.stablecoin_contract);
        storage.max = amount;
    }

    #[storage(read)]
    fn get_stablecoin_contract() -> b256 {
        storage.stablecoin_contract
    }
}