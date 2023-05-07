library balancesheetmodule_abi;

use signed_integers::i256::I256;

abi BalanceSheetModule {
    #[storage(read)]
    fn total_surplus() -> I256;

    #[storage(read, write)]
    fn add_surplus(amount: I256);

    #[storage(read, write)]
    fn add_deficit(amount: I256);
    
    #[storage(read, write)]
    fn set_surplus(amount: I256);

    #[storage(read)]
    fn get_handler() -> b256;

    #[storage(read)]
    fn get_stablecoin_contract() -> b256;

    #[storage(read, write)]
    fn set_handler(handler: b256);
}