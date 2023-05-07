library psmlockup_abi;

use fixed_point::ufp128::UFP128;
use yama_types::ufp128::*;

abi PSMLockup {
    #[storage(read, write)]
    fn set_bsh_contract(bsh_contract: b256);

    #[payable]
    #[storage(read, write)]
    fn lockup() -> u64;

    #[payable]
    #[storage(read, write)]
    fn redeem() -> u64;

    #[storage(read)]
    fn value() -> UFP128;

    #[storage(read)]
    fn total_supply() -> u64;

    #[storage(read)]
    fn name() -> str[64];

    #[storage(read)]
    fn symbol() -> str[32];

    #[storage(read)]
    fn decimals() -> u8;

    #[storage(read)]
    fn get_stablecoin_contract() -> b256;

    #[storage(read)]
    fn get_token() -> b256;

    #[storage(read)]
    fn get_psm_contract() -> b256;

    #[storage(read)]
    fn get_bsh_contract() -> b256;
}