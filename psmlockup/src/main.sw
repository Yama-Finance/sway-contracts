contract;

use yama_interfaces::{
    psmlockup_abi::PSMLockup,
    simplebsh_abi::SimpleBSH,
    pegstabilitymodule_abi::PegStabilityModule,
    events::{
        Lockup,
        Redeem
    }
};
use fixed_point::ufp128::UFP128;
use yama_types::ufp128::*;
use std::{
    token::{
        mint_to,
        burn,
        transfer
    },
    logging::log,
    context::{
        msg_amount,
        this_balance
    },
    call_frames::contract_id
};
use stablecoin_library::{
    helpers::{
        verify_sender_allowed,
        verify_tokens_from,
        tokens_to_fp,
        fp_to_tokens,
        sender_id
    },
    constants::{
        ZERO_B256,
        DECIMALS,
        STR_64,
        STR_32
    }
};

storage {
    stablecoin_contract: b256 = ZERO_B256,
    token: b256 = ZERO_B256,
    psm_contract: b256 = ZERO_B256,
    bsh_contract: b256 = ZERO_B256,
    name: str[64] = STR_64,
    symbol: str[32] = STR_32,
    total_supply: u64 = 0
}

impl PSMLockup for Contract {
    #[storage(read, write)]
    fn set_bsh_contract(bsh_contract: b256) {
        verify_sender_allowed(storage.stablecoin_contract);
        storage.bsh_contract = bsh_contract;
    }

    #[payable]
    #[storage(read, write)]
    fn lockup() -> u64 {
        verify_tokens_from(storage.token);
        let bsh = abi(SimpleBSH, storage.bsh_contract);
        bsh.process_pending_share_amount();
        let saved_value = value();
        let psm = abi(PegStabilityModule, storage.psm_contract);
        let yama_amount = psm.deposit {
            coins: msg_amount(),
            asset_id: storage.token
        } ();
        let lockup_amount = fp_to_tokens(tokens_to_fp(yama_amount) / saved_value);
        mint_to(lockup_amount, sender_id());
        log(Lockup {
            account: sender_id(),
            ext_stable_amount: msg_amount(),
            yama_amount: yama_amount,
            lockup_amount: lockup_amount
        });

        storage.total_supply += lockup_amount;

        lockup_amount
    }

    #[payable]
    #[storage(read, write)]
    fn redeem() -> u64 {
        verify_tokens_from(contract_id().value);
        let yama_amount = fp_to_tokens(tokens_to_fp(msg_amount()) * value());
        burn(msg_amount());
        transfer(
            yama_amount,
            ContractId::from(storage.stablecoin_contract),
            sender_id()
        );
        log(Redeem {
            account: sender_id(),
            yama_amount: yama_amount,
            lockup_amount: msg_amount()
        });

        storage.total_supply -= msg_amount();

        yama_amount
    }

    #[storage(read)]
    fn value() -> UFP128 {
        value()
    }

    #[storage(read)]
    fn total_supply() -> u64 {
        storage.total_supply
    }

    #[storage(read)]
    fn name() -> str[64] {
        storage.name
    }

    #[storage(read)]
    fn symbol() -> str[32] {
        storage.symbol
    }

    #[storage(read)]
    fn decimals() -> u8 {
        DECIMALS
    }

    #[storage(read)]
    fn get_stablecoin_contract() -> b256 {
        storage.stablecoin_contract
    }

    #[storage(read)]
    fn get_token() -> b256 {
        storage.token
    }

    #[storage(read)]
    fn get_psm_contract() -> b256 {
        storage.psm_contract
    }

    #[storage(read)]
    fn get_bsh_contract() -> b256 {
        storage.bsh_contract
    }
}

#[storage(read)]
fn value() -> UFP128 {
    if storage.total_supply == 0 {
        return UFP128::from_uint(1);
    }
    tokens_to_fp(this_balance(
        ContractId::from(storage.stablecoin_contract)))
        / tokens_to_fp(storage.total_supply)
}