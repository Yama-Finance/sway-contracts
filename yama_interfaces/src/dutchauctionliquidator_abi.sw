library dutchauctionliquidator_abi;

use fixed_point::ufp128::UFP128;
use yama_types::ufp128::*;

pub struct CTypeParams {
    initial_price_ratio: UFP128,
    time_interval: u64,
    change_rate: UFP128,
    reset_threshold: u64,
    enabled: bool
}

pub struct Auction {
    vault_id: u64,
    start_price: UFP128,
    start_time: u64,
    done: bool
}

abi DutchAuctionLiquidator {
    #[storage(read, write)]
    fn set_c_type_params(
        collateral_type_id: u64,
        initial_price_ratio: UFP128,
        time_interval: u64,
        change_rate: UFP128,
        reset_threshold: u64,
        enabled: bool
    );

    #[storage(read, write)]
    fn set_default_c_type_params(
        initial_price_ratio: UFP128,
        time_interval: u64,
        change_rate: UFP128,
        reset_threshold: u64
    );

    #[storage(read, write)]
    fn liquidate(vault_id: u64);

    #[payable]
    #[storage(read, write)]
    fn claim(auction_id: u64, max_price: u64);

    #[storage(read, write)]
    fn reset_auction(auction_id: u64);

    #[storage(read)]
    fn get_collateral_type_id(auction_id: u64) -> u64;

    #[storage(read)]
    fn get_price(auction_id: u64) -> u64;

    #[storage(read)]
    fn is_expired(auction_id: u64) -> bool;

    #[storage(read)]
    fn get_c_type_params(collateral_type_id: u64) -> CTypeParams;

    #[storage(read)]
    fn get_auction(auction_id: u64) -> Auction;

    #[storage(read)]
    fn get_default_c_type_params() -> CTypeParams;

    #[storage(read)]
    fn get_collateral_amount_of_auction(auction_id: u64) -> u64;

    // Sets the balancesheet module
    #[storage(read, write)]
    fn set_balancesheet_module(value: b256);

    #[storage(read)]
    fn get_stablecoin_contract() -> b256;

    #[storage(read)]
    fn get_balancesheet_module() -> b256;

    #[storage(read)]
    fn get_cdp_module() -> b256;
}