library flashmintmodule_abi;

abi FlashMintModule {
    #[storage(read, write)]
    fn flash_loan(
        amount: u64,
        calldata: Vec<u8>
    );

    #[payable]
    #[storage(read, write)]
    fn repay();

    #[storage(read)]
    fn get_max() -> u64;

    #[storage(read, write)]
    fn set_max(amount: u64);

    #[storage(read)]
    fn get_stablecoin_contract() -> b256;
}