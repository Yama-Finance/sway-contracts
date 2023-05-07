library leverageproxy_abi;

abi LeverageProxy {
    #[storage(read, write)]
    fn set_collateral_type_config(
        collateral_type_id: u64,
        collateral: b256,
        swapper: b256
    );

    #[storage(read, write)]
    fn leverage_up(
        vault_id: u64,
        yama_borrowed: u64,
        min_collat_swapped: u64,
    );

    #[storage(read, write)]
    fn leverage_down(
        vault_id: u64,
        collat_sold: u64,
        min_yama_repaid: u64,
    );

    #[storage(read, write)]
    fn leverage_down_all(
        vault_id: u64,
        collat_sold: u64
    );

    #[payable]
    #[storage(read, write)]
    fn create_vault(
        collateral_type_id: u64
    ) -> u64;

    #[storage(read, write)]
    fn flash_loan_callback(
        initiator: Identity,
        amount: u64,
        calldata: Vec<u8>
    );

    #[storage(read)]
    fn get_stablecoin_contract() -> b256;

    #[storage(read)]
    fn get_flash_mint_module() -> b256;

    #[storage(read)]
    fn get_cdp_module() -> b256;

    #[storage(read)]
    fn get_collateral(collateral_type_id: u64) -> b256;

    #[storage(read)]
    fn get_swapper(collateral_type_id: u64) -> b256;
}