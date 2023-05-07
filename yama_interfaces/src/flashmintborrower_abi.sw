library flashmintborrower_abi;

abi FlashMintBorrower {
    #[storage(read, write)]
    fn flash_loan_callback(
        initiator: Identity,
        amount: u64,
        calldata: Vec<u8>
    );
}