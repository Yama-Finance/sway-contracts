contract;

use std::{
    token::transfer,
    context::{
        msg_amount,
        this_balance
    },
    logging::log
};

use stablecoin_library::{
    constants::{
        DECIMALS,
        PSM_CEILING,
        ZERO_B256,
        PSM_TOKEN_DECIMALS
    },
    helpers::{
        sender_id,
        mint,
        burn,
        verify_sender_allowed,
        verify_tokens_from,
        convert_amount
    }
};

use yama_interfaces::{
    pegstabilitymodule_abi::PegStabilityModule,
    events::{
        SetDebtCeiling,
        Deposit,
        Withdraw
    },
    errors::PSMError
};

storage {
    stablecoin_contract: b256 = ZERO_B256,
    token: b256 = ZERO_B256,
    debt_ceiling: u64 = PSM_CEILING,
    yss_decimals: u8 = DECIMALS,
    external_stable_decimals: u8 = PSM_TOKEN_DECIMALS
}

impl PegStabilityModule for Contract {
    #[storage(read, write)]
    fn set_debt_ceiling(debt_ceiling: u64) {
        verify_sender_allowed(storage.stablecoin_contract);
        storage.debt_ceiling = debt_ceiling;

        log(SetDebtCeiling {
            account: sender_id(),
            debt_ceiling: debt_ceiling
        });
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
    fn debt_ceiling() -> u64 {
        storage.debt_ceiling
    }

    #[storage(read)]
    fn get_yss_decimals() -> u8 {
        storage.yss_decimals
    }

    #[storage(read)]
    fn get_external_stable_decimals() -> u8 {
        storage.external_stable_decimals
    }

    #[storage(read)]
    fn transfer(token: ContractId, to: Identity, amount: u64) {
        verify_sender_allowed(storage.stablecoin_contract);
        if amount > 0 {
            transfer(amount, token, to);
        }
    }

    #[payable]
    #[storage(read)]
    fn deposit() -> u64 {
        verify_tokens_from(storage.token);
        let yama_amount: u64 = convert_amount(
            msg_amount(),
            storage.external_stable_decimals,
            storage.yss_decimals
        );
        mint(
            yama_amount,
            sender_id(),
            storage.stablecoin_contract
        );
        log(Deposit {
            account: sender_id(),
            ext_stable_amount: msg_amount()
        });
        require(
            this_balance(ContractId::from(storage.token)) <= storage.debt_ceiling,
            PSMError::ExceedsDebtCeiling
        );
        yama_amount
    }

    #[payable]
    #[storage(read)]
    fn withdraw() -> u64 {
        verify_tokens_from(storage.stablecoin_contract);
        burn(msg_amount(), storage.stablecoin_contract);
        let ext_stable_amount: u64 = convert_amount(
            msg_amount(),
            storage.yss_decimals,
            storage.external_stable_decimals
        );
        transfer(
            ext_stable_amount,
            ContractId::from(storage.token),
            sender_id()
        );
        log(Withdraw {
            account: sender_id(),
            yss_amount: msg_amount()
        });
        
        ext_stable_amount
    }
}
