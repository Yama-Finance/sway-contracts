contract;

use yama_interfaces::{
    dutchauctionliquidator_abi::{
        DutchAuctionLiquidator,
        CTypeParams,
        Auction
    },
    errors::DutchAuctionLiquidatorError,
    events::{
        InitializeAuction,
        ResetAuction,
        ClaimAuction,
        SetDefaultCTypeParams,
        SetCTypeParams
    },
    cdpmodule_abi::CDPModule
};
use fixed_point::ufp128::UFP128;
use yama_types::ufp128::*;
use stablecoin_library::{
    constants::{
        ZERO_B256,
        DAL_DEFAULT_INITIAL_PRICE_RATIO,
        DAL_DEFAULT_TIME_INTERVAL,
        DAL_CHANGE_RATE,
        DAL_RESET_THRESHOLD,
        DAL_ENABLED
    },
    helpers::{
        sender_id,
        burn,
        add_surplus,
        verify_sender_allowed,
        verify_tokens_from,
        tokens_to_fp,
        u64_to_i256
    }
};

use std::{
    storage::StorageVec,
    block::timestamp,
    context::msg_amount,
    u256::U256,
    logging::log,
    token::transfer
};

use signed_integers::i256::I256;

storage {
    stablecoin_contract: b256 = ZERO_B256,
    balancesheet_module: b256 = ZERO_B256,
    cdp_module: b256 = ZERO_B256,
    // Due to limitations with initialization of structs, this must be set upon
    // deployment
    default_c_type_params: CTypeParams = CTypeParams {
        initial_price_ratio: DAL_DEFAULT_INITIAL_PRICE_RATIO,
        time_interval: DAL_DEFAULT_TIME_INTERVAL,
        change_rate: DAL_CHANGE_RATE,
        reset_threshold: DAL_RESET_THRESHOLD,
        enabled: DAL_ENABLED  // Ignored
    },
    auctions: StorageVec<Auction> = StorageVec{},
    c_type_params_mapping: StorageMap<u64, CTypeParams> = StorageMap{}
}

impl DutchAuctionLiquidator for Contract {
    #[storage(read, write)]
    fn set_c_type_params(
        collateral_type_id: u64,
        initial_price_ratio: UFP128,
        time_interval: u64,
        change_rate: UFP128,
        reset_threshold: u64,
        enabled: bool
    ) {
        verify_sender_allowed(storage.stablecoin_contract);
        storage.c_type_params_mapping.insert(collateral_type_id, CTypeParams {
            initial_price_ratio: initial_price_ratio,
            time_interval: time_interval,
            change_rate: change_rate,
            reset_threshold: reset_threshold,
            enabled: enabled
        });

        log(SetCTypeParams {
            collateral_type_id: collateral_type_id,
            initial_price_ratio: initial_price_ratio,
            time_interval: time_interval,
            change_rate: change_rate,
            reset_threshold: reset_threshold,
            enabled: enabled
        });
    }

    #[storage(read, write)]
    fn set_default_c_type_params(
        initial_price_ratio: UFP128,
        time_interval: u64,
        change_rate: UFP128,
        reset_threshold: u64
    ) {
        verify_sender_allowed(storage.stablecoin_contract);
        storage.default_c_type_params = CTypeParams {
            initial_price_ratio: initial_price_ratio,
            time_interval: time_interval,
            change_rate: change_rate,
            reset_threshold: reset_threshold,
            enabled: true
        };
        
        log(SetDefaultCTypeParams {
            initial_price_ratio: initial_price_ratio,
            time_interval: time_interval,
            change_rate: change_rate,
            reset_threshold: reset_threshold
        });
    }

    #[storage(read, write)]
    fn liquidate(vault_id: u64) {
        verify_sender_allowed(storage.stablecoin_contract);
        initialize_auction(vault_id);
    }

    #[payable]
    #[storage(read, write)]
    fn claim(auction_id: u64, max_price: u64) {
        verify_not_done(auction_id);
        require(!is_expired(auction_id),
            DutchAuctionLiquidatorError::AuctionExpired);
        let price: u64 = get_price(auction_id);
        verify_tokens_from(storage.stablecoin_contract);
        require(msg_amount() >= price,
            DutchAuctionLiquidatorError::InvalidPayment);
        
        require(price <= max_price,
            DutchAuctionLiquidatorError::ExceedsMaxPrice);
        
        burn(price, storage.stablecoin_contract);

        if msg_amount() > price {
            transfer(
                msg_amount() - price,
                ContractId::from(storage.stablecoin_contract),
                sender_id()
            );
        }

        let mut auction: Auction = get_auction(auction_id);

        let cdpmodule = abi(CDPModule, storage.cdp_module);

        let token = cdpmodule.get_collateral_token(auction.vault_id);
        let amount = cdpmodule.get_collateral_amount(auction.vault_id);

        cdpmodule.transfer(
            token,
            sender_id(),
            amount
        );

        cdpmodule.update_interest(
            cdpmodule.get_collateral_type_id(auction.vault_id));
        add_surplus(
            u64_to_i256(price) - u64_to_i256(cdpmodule.get_debt(auction.vault_id)),
            storage.balancesheet_module
        );

        cdpmodule.clear_vault(auction.vault_id);

        auction.done = true;
        storage.auctions.set(auction_id, auction);

        log(ClaimAuction {
            claimer: sender_id(),
            vault_id: auction.vault_id,
            auction_id: auction_id,
            price: price
        });
    }

    #[storage(read, write)]
    fn reset_auction(auction_id: u64) {
        verify_not_done(auction_id);
        require(is_expired(auction_id),
            DutchAuctionLiquidatorError::AuctionNotExpired);
        let mut auction: Auction = get_auction(auction_id);
        auction.done = true;
        storage.auctions.set(auction_id, auction);

        log(ResetAuction {
            initiator: sender_id(),
            vault_id: auction.vault_id,
            auction_id: auction_id
        });

        initialize_auction(auction.vault_id);
    }

    #[storage(read)]
    fn get_collateral_type_id(auction_id: u64) -> u64 {
        get_collateral_type_id_of_auction(auction_id)
    }

    #[storage(read)]
    fn get_price(auction_id: u64) -> u64 {
        get_price(auction_id)
    }

    #[storage(read)]
    fn is_expired(auction_id: u64) -> bool {
        is_expired(auction_id)
    }

    #[storage(read)]
    fn get_default_c_type_params() -> CTypeParams {
        storage.default_c_type_params
    }

    #[storage(read)]
    fn get_collateral_amount_of_auction(auction_id: u64) -> u64 {
        get_collateral_amount_of_auction(auction_id)
    }

    #[storage(read, write)]
    fn set_balancesheet_module(value: b256) {
        verify_sender_allowed(storage.stablecoin_contract);
        storage.balancesheet_module = value;
    }

    #[storage(read)]
    fn get_c_type_params(collateral_type_id: u64) -> CTypeParams {
        get_c_type_params(collateral_type_id)
    }

    #[storage(read)]
    fn get_auction(auction_id: u64) -> Auction {
        get_auction(auction_id)
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
    fn get_cdp_module() -> b256 {
        storage.cdp_module
    }
}

#[storage(read, write)]
fn initialize_auction(vault_id: u64) {
    let c_type_params: CTypeParams = get_c_type_params(
        get_collateral_type_id_of_vault(vault_id)
    );

    let auction: Auction = Auction {
        vault_id: vault_id,
        start_price: get_collateral_value(vault_id)
            * c_type_params.initial_price_ratio,
        start_time: timestamp(),
        done: false
    };

    storage.auctions.push(auction);

    log(InitializeAuction {
        vault_id: vault_id,
        auction_id: storage.auctions.len() - 1,
        start_price: auction.start_price,
        start_time: auction.start_time
    });
}

#[storage(read)]
fn get_c_type_params(collateral_type_id: u64) -> CTypeParams {
    let specific_c_type_params = storage.c_type_params_mapping.get(
        collateral_type_id);
    
    if (specific_c_type_params.is_some()
        && specific_c_type_params.unwrap().enabled
    ) {
        return specific_c_type_params.unwrap();
    } else {
        return storage.default_c_type_params;
    }
}


#[storage(read)]
fn get_collateral_type_id_of_vault(vault_id: u64) -> u64 {
    let cdpmodule = abi(CDPModule, storage.cdp_module);
    cdpmodule.get_collateral_type_id(vault_id)
}
#[storage(read)]
fn get_collateral_value(vault_id: u64) -> UFP128 {
    let cdpmodule = abi(CDPModule, storage.cdp_module);
    tokens_to_fp(cdpmodule.get_collateral_value(vault_id))
}

#[storage(read)]
fn get_auction(auction_id: u64) -> Auction {
    storage.auctions.get(auction_id).unwrap()
}

#[storage(read)]
fn get_collateral_type_id_of_auction(auction_id: u64) -> u64 {
    get_collateral_type_id_of_vault(get_auction(auction_id).vault_id)
}

#[storage(read)]
fn get_auction_c_type_params(auction_id: u64) -> CTypeParams {
    get_c_type_params(get_collateral_type_id_of_auction(auction_id))
}

#[storage(read)]
fn get_collateral_amount_of_auction(auction_id: u64) -> u64 {
    let cdpmodule = abi(CDPModule, storage.cdp_module);
    cdpmodule.get_collateral_amount(get_auction(auction_id).vault_id)
}

#[storage(read)]
fn verify_not_done(auction_id: u64) {
    require(!get_auction(auction_id).done,
        DutchAuctionLiquidatorError::AuctionDone);
}

#[storage(read)]
fn get_price(auction_id: u64) -> u64 {
    let auction: Auction = get_auction(auction_id);

    if (auction.done || is_expired(auction_id)) {
        return 0;
    }

    let c_type_params: CTypeParams = get_auction_c_type_params(auction_id);

    let intervals_elapsed: u64 = (timestamp() - auction.start_time)
        / c_type_params.time_interval;
    
    (auction.start_price * c_type_params.change_rate.powu(intervals_elapsed))
        .to_u64()
}

#[storage(read)]
fn is_expired(auction_id: u64) -> bool {
    let c_type_params: CTypeParams = get_auction_c_type_params(auction_id);

    timestamp() >= (get_auction(auction_id).start_time
        + (c_type_params.time_interval * c_type_params.reset_threshold))
}