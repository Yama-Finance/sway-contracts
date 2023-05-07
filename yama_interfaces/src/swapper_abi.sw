library swapper_abi;

abi Swapper {
    #[payable]
    #[storage(read, write)]
    fn swap_to_yama(min_output_amount: u64) -> u64;

    #[payable]
    #[storage(read, write)]
    fn swap_to_collateral(min_output_amount: u64) -> u64;
}