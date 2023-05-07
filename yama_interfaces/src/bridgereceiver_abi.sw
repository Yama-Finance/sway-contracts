library bridgereceiver_abi;

abi BridgeReceiver {
    #[storage(read, write)]
    fn yama_bridge_callback(
        src_chain: u32,
        from_id: b256,
        amount: u64,
        payload: Vec<u8>
    );
}