library liquidator_abi;

abi Liquidator {
    // Called by the CDP module to liquidate a vault
    #[storage(read, write)]
    fn liquidate(vault_id: u64);
}