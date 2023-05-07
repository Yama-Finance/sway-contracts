contract;

use yama_interfaces::emptycollateralmanager_abi::EmptyCollateralManager;

impl EmptyCollateralManager for Contract {
    #[storage(read, write)]
    fn handle_collateral_deposit(vault_id: u64, amount: u64) {}

    #[storage(read, write)]
    fn handle_collateral_withdrawal(vault_id: u64, amount: u64) {}
}