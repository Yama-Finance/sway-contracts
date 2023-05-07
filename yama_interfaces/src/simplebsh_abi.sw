library simplebsh_abi;

use signed_integers::i256::I256;

abi SimpleBSH {
    #[storage(read, write)]
    fn on_add_surplus(amount: I256);

    #[storage(read, write)]
    fn on_add_deficit(amount: I256);

    #[storage(read, write)]
    fn get_revenue_share() -> u64;

    #[storage(read, write)]
    fn set_revenue_share(amount: u64);

    #[storage(read, write)]
    fn process_pending_share_amount();

    // Sets the balancesheet module
    #[storage(read, write)]
    fn set_balancesheet_module(value: b256);

    #[storage(read)]
    fn get_stablecoin_contract() -> b256;

    #[storage(read)]
    fn get_balancesheet_module() -> b256;

    #[storage(read)]
    fn get_target() -> b256;

    #[storage(read)]
    fn get_pending_share_amount() -> I256;

    #[storage(read)]
    fn get_last_block_update() -> u64;
}