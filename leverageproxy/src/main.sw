contract;

use yama_interfaces::{
    leverageproxy_abi::LeverageProxy,
    flashmintmodule_abi::FlashMintModule,
    cdpmodule_abi::CDPModule,
    swapper_abi::Swapper,
    errors::LeverageProxyError
};
use stablecoin_library::{
    helpers::{
        verify_sender_allowed,
        verify_tokens_from,
        flash_loan,
        sender_id
    },
    constants::ZERO_B256
};
use std::{
    call_frames::contract_id,
    token::transfer,
    bytes::Bytes,
    context::msg_amount
};
use bytes_extended::*;

storage {
    stablecoin_contract: b256 = ZERO_B256,
    flash_mint_module: b256 = ZERO_B256,
    cdp_module: b256 = ZERO_B256,
    collateral_mapping: StorageMap<u64, b256> = StorageMap{},
    swapper_mapping: StorageMap<u64, b256> = StorageMap{},
}

impl LeverageProxy for Contract {
    #[storage(read, write)]
    fn set_collateral_type_config(
        collateral_type_id: u64,
        collateral: b256,
        swapper: b256
    ) {
        verify_sender_allowed(storage.stablecoin_contract);
        storage.collateral_mapping.insert(collateral_type_id, collateral);
        storage.swapper_mapping.insert(collateral_type_id, swapper);
    }

    #[storage(read, write)]
    fn leverage_up(
        vault_id: u64,
        yama_borrowed: u64,
        min_collat_swapped: u64,
    ) {
        verify_sender_owns_vault(vault_id);
        flash_loan(
            yama_borrowed,
            encode_flash_loan_data(true, vault_id, min_collat_swapped, sender_id()),
            storage.flash_mint_module,
        );
    }

    #[storage(read, write)]
    fn leverage_down(
        vault_id: u64,
        collat_sold: u64,
        min_yama_repaid: u64,
    ) {
        leverage_down(
            vault_id,
            collat_sold,
            min_yama_repaid
        );
    }

    #[storage(read, write)]
    fn leverage_down_all(
        vault_id: u64,
        collat_sold: u64
    ) {
        let cdp_contract = abi(CDPModule, storage.cdp_module);
        cdp_contract.update_interest(
            cdp_contract.get_collateral_type_id(vault_id)
        );
        let min_yama_repaid = cdp_contract.get_debt(vault_id);
        leverage_down(
            vault_id,
            collat_sold,
            min_yama_repaid
        );
    }

    #[payable]
    #[storage(read, write)]
    fn create_vault(
        collateral_type_id: u64
    ) -> u64 {
        let collateral = storage.collateral_mapping.get(collateral_type_id).unwrap();
        verify_tokens_from(collateral);
        let cdp_contract = abi(CDPModule, storage.cdp_module);
        cdp_contract.create_vault{
            coins: msg_amount(),
            asset_id: collateral,
        }(collateral_type_id, Option::Some(sender_id()))
    }

    #[storage(read, write)]
    fn flash_loan_callback(
        initiator: Identity,
        amount: u64,
        calldata: Vec<u8>
    ) {
        require(sender_id() == Identity::ContractId(
            ContractId::from(storage.flash_mint_module)),
            LeverageProxyError::NotFlashMintModule);
        require(initiator == Identity::ContractId(contract_id()),
            LeverageProxyError::InitiatorNotThis);
        
        let (
            is_leveraging_up,
            vault_id,
            collat_amount,
            executor
        ) = decode_flash_loan_data(calldata);

        let cdp_contract = abi(CDPModule, storage.cdp_module);

        let collateral_type_id = cdp_contract.get_collateral_type_id(vault_id);
        let collateral = storage.collateral_mapping.get(collateral_type_id).unwrap();
        let swapper = abi(
            Swapper, storage.swapper_mapping.get(collateral_type_id).unwrap());
        if is_leveraging_up {
            let output_collat_amount = swapper.swap_to_collateral{
                coins: amount,
                asset_id: storage.stablecoin_contract,
            }(collat_amount);
            cdp_contract.add_collateral{
                coins: output_collat_amount,
                asset_id: collateral,
            }(vault_id);
            cdp_contract.borrow(vault_id, amount);
        } else {
            cdp_contract.repay{
                coins: amount,
                asset_id: storage.stablecoin_contract,
            }(vault_id);
            cdp_contract.remove_collateral(vault_id, collat_amount);
            let profit = swapper.swap_to_yama{
                coins: collat_amount,
                asset_id: collateral,
            }(amount) - amount;
            transfer(
                profit,
                ContractId::from(storage.stablecoin_contract),
                executor
            );
        }
        let flash_mint_contract = abi(
            FlashMintModule, storage.flash_mint_module);
        flash_mint_contract.repay{
            coins: amount,
            asset_id: storage.stablecoin_contract,
        }();
    }

    #[storage(read)]
    fn get_stablecoin_contract() -> b256 {
        storage.stablecoin_contract
    }

    #[storage(read)]
    fn get_flash_mint_module() -> b256 {
        storage.flash_mint_module
    }

    #[storage(read)]
    fn get_cdp_module() -> b256 {
        storage.cdp_module
    }

    #[storage(read)]
    fn get_collateral(collateral_type_id: u64) -> b256 {
        storage.collateral_mapping.get(collateral_type_id).unwrap()
    }

    #[storage(read)]
    fn get_swapper(collateral_type_id: u64) -> b256 {
        storage.swapper_mapping.get(collateral_type_id).unwrap()
    }
}

const LEVERAGING_UP_OFFSET = 0;
const VAULT_ID_OFFSET = 1;
const COLLAT_AMOUNT_OFFSET = 9;
const IS_CONTRACT_OFFSET = 17;
const EXECUTOR_OFFSET = 18;

fn encode_flash_loan_data(
    is_leveraging_up: bool,
    vault_id: u64,
    collat_amount: u64,
    executor: Identity
) -> Vec<u8> {
    let mut data = Bytes::new();
    data.write_u8(
        LEVERAGING_UP_OFFSET,
        if is_leveraging_up { 1 } else { 0 }
    );
    data.write_u64(VAULT_ID_OFFSET, vault_id);
    data.write_u64(COLLAT_AMOUNT_OFFSET, collat_amount);
    let is_contract = match executor {
        Identity::Address(_) => 0,
        Identity::ContractId(_) => 1,
    };
    data.write_u8(IS_CONTRACT_OFFSET, is_contract);
    let executor_b: b256 = match executor {
        Identity::Address(address) => address.into(),
        Identity::ContractId(cid) => cid.into(),
    };
    data.write_b256(EXECUTOR_OFFSET, executor_b);
    data.into_vec_u8()
}

fn decode_flash_loan_data(data: Vec<u8>) -> (bool, u64, u64, Identity) {
    let mut data = data;
    let data: Bytes = Bytes::from_vec_u8(data);
    let is_leveraging_up = data.read_u8(LEVERAGING_UP_OFFSET) == 1;
    let vault_id = data.read_u64(VAULT_ID_OFFSET);
    let collat_amount = data.read_u64(COLLAT_AMOUNT_OFFSET);
    let is_contract = data.read_u8(IS_CONTRACT_OFFSET) == 1;
    let executor_b = data.read_b256(EXECUTOR_OFFSET);
    let executor = if is_contract {
        Identity::ContractId(ContractId::from(executor_b))
    } else {
        Identity::Address(Address::from(executor_b))
    };
    (is_leveraging_up, vault_id, collat_amount, executor)
}

#[storage(read)]
fn verify_sender_owns_vault(vault_id: u64) {
    let cdp_contract = abi(CDPModule, storage.cdp_module);
    require(cdp_contract.get_alt_owner(vault_id).unwrap() == sender_id(),
        LeverageProxyError::NotVaultOwner);
}

#[storage(read, write)]
fn leverage_down(
    vault_id: u64,
    collat_sold: u64,
    min_yama_repaid: u64,
) {
    verify_sender_owns_vault(vault_id);
    flash_loan(
        min_yama_repaid,
        encode_flash_loan_data(false, vault_id, collat_sold, sender_id()),
        storage.flash_mint_module,
    );
}