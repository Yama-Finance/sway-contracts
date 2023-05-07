library bridgemodule_abi;

abi BridgeModule {
    // Transfers YAMA from the sender's wallet to a remote chain
    #[payable]
    #[storage(read)]
    fn transfer_remote(
        dst_chain: u32,
        to_id: b256,
        metadata: u32,
        receiver_payload: Vec<u8>
    );

    // Handles incoming Hyperlane messages
    #[storage(read, write)]
    fn handle(origin: u32, sender: b256, message_body: Vec<u8>);

    // Sets decimals for a chain
    #[storage(read, write)]
    fn set_decimals(chain: u32, decimals: u8);

    // Sets the bridge
    #[storage(read, write)]
    fn set_bridge(chain: u32, bridge: b256);

    // Sets the alternate bridge
    #[storage(read, write)]
    fn set_alt_bridge(chain: u32, alt_bridge: b256, is_alt_bridge: bool);

    // Sets the Hyperlane mailbox
    #[storage(read, write)]
    fn set_mailbox(mailbox: b256);

    #[storage(read)]
    fn get_stablecoin_contract() -> b256;

    #[storage(read)]
    fn get_mailbox() -> b256;

    #[storage(read)]
    fn get_bridge_id(chain: u32) -> b256;

    #[storage(read)]
    fn get_alt_bridge_id(chain: u32, alt_bridge: b256) -> bool;

    #[storage(read)]
    fn get_decimals(chain: u32) -> u8;
}