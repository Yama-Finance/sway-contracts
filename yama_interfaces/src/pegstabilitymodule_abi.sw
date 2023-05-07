library pegstabilitymodule_abi;

dep events;
dep errors;

abi PegStabilityModule {
    // Sets the debt ceiling
    #[storage(read, write)]
    fn set_debt_ceiling(debt_ceiling: u64);

    // Used by allowed contracts to transfer tokens out
    #[storage(read)]
    fn transfer(token: ContractId, to: Identity, amount: u64);

    // Deposits the external stablecoin in exchange for YSS
    #[payable]
    #[storage(read)]
    fn deposit() -> u64;

    // Withdraws the external stablecoin by burning YSS
    #[payable]
    #[storage(read)]
    fn withdraw() -> u64;

    #[storage(read)]
    fn get_stablecoin_contract() -> b256;

    #[storage(read)]
    fn get_token() -> b256;

    #[storage(read)]
    fn debt_ceiling() -> u64;

    #[storage(read)]
    fn get_yss_decimals() -> u8;

    #[storage(read)]
    fn get_external_stable_decimals() -> u8;
}