library collateralmanager_abi;

abi CollateralManager {
    // Can be used by the protocol to execute code upon funds being deposited
    #[storage(read, write)]
    fn handle_collateral_deposit(vault_id: u64, amount: u64);

    // Can be used by the protocol to execute code upon funds being withdrawn
    #[storage(read, write)]
    fn handle_collateral_withdrawal(vault_id: u64, amount: u64);
}