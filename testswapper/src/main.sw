contract;

use yama_interfaces::{
    swapper_abi::Swapper,
    errors::SwapperError
};
use stablecoin_library::{
    constants::ZERO_B256,
    helpers::{
        sender_id,
        mint,
        burn,
        verify_tokens_from
    }
};

use std::{
    context::msg_amount
};

abi TestSwapper {
    #[payable]
    #[storage(read, write)]
    fn swap_to_yama(min_output_amount: u64) -> u64;

    #[payable]
    #[storage(read, write)]
    fn swap_to_collateral(min_output_amount: u64) -> u64;
}

storage {
    collateral: b256 = ZERO_B256,
    stablecoin: b256 = ZERO_B256
}

impl TestSwapper for Contract {
    #[payable]
    #[storage(read, write)]
    fn swap_to_yama(min_output_amount: u64) -> u64 {
        verify_tokens_from(storage.collateral);
        require(
            msg_amount() >= min_output_amount,
            SwapperError::InsufficientInput
        );
        burn(
            msg_amount(),
            storage.collateral
        );
        mint(
            msg_amount(),
            sender_id(),
            storage.stablecoin
        );

        msg_amount()
    }

    #[payable]
    #[storage(read, write)]
    fn swap_to_collateral(min_output_amount: u64) -> u64 {
        verify_tokens_from(storage.stablecoin);
        require(
            msg_amount() >= min_output_amount,
            SwapperError::InsufficientInput
        );
        burn(
            msg_amount(),
            storage.stablecoin
        );
        mint(
            msg_amount(),
            sender_id(),
            storage.collateral
        );

        msg_amount()
    }
}
