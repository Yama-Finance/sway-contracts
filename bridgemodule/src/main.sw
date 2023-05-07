contract;

use std::{
    bytes::Bytes,
    context::msg_amount,
    logging::log,
    u256::U256
};
use bytes_extended::*;
use stablecoin_library::{
    helpers::{
        sender_id,
        burn,
        mint,
        verify_tokens_from,
        verify_sender_allowed,
        convert_amount_u256
    },
    constants::{
        ZERO_B256,
        DECIMALS
    }
};
use yama_interfaces::{
    bridgemodule_abi::BridgeModule,
    events::{
        RemoteTransferSent,
        RemoteTransferReceived,
        SetBridge
    },
    errors::BridgeError,
    bridgereceiver_abi::BridgeReceiver
};

use hyperlane_interfaces::Mailbox;

const VERSION_OFFSET: u64 = 0;
const FROM_ID_OFFSET: u64 = 1;
const TO_ID_OFFSET: u64 = 33;
const METADATA_OFFSET: u64 = 65;
const AMOUNT_OFFSET: u64 = 69;
const RECEIVER_PAYLOAD_OFFSET: u64 = 101;

storage {
    stablecoin_contract: b256 = ZERO_B256,
    mailbox: b256 = ZERO_B256,
    bridge_id: StorageMap<u32, b256> = StorageMap{},
    alt_bridge_id: StorageMap<(u32, b256), bool> = StorageMap{},
    decimals: StorageMap<u32, u8> = StorageMap{}
}

impl BridgeModule for Contract {
    #[payable]
    #[storage(read)]
    fn transfer_remote(
        dst_chain: u32,
        to_id: b256,
        metadata: u32,
        receiver_payload: Vec<u8>
    ) {
        verify_tokens_from(storage.stablecoin_contract);
        burn(msg_amount(), storage.stablecoin_contract);

        let payload: Vec<u8> = encode_payload(
            sender_id(),
            to_id,
            metadata,
            msg_amount(),
            storage.decimals.get(dst_chain).unwrap(),
            receiver_payload
        );

        let mailbox = abi(Mailbox, storage.mailbox);
        mailbox.dispatch(
            dst_chain,
            storage.bridge_id.get(dst_chain).unwrap(),
            payload
        );

        log(RemoteTransferSent {
            from_id: sender_id(),
            dst_chain: dst_chain,
            to_id: to_id,
            metadata: metadata,
            amount: msg_amount()
        });
    }

    #[storage(read, write)]
    fn handle(origin: u32, sender: b256, message_body: Vec<u8>) {
        require (
            sender_id()
                == Identity::ContractId(ContractId::from(storage.mailbox)),
            BridgeError::NotMailbox
        );
        require(
            storage.alt_bridge_id.get((origin, sender)).unwrap_or(false)
            || sender == storage.bridge_id.get(origin).unwrap(),
            BridgeError::InvalidSourceBridge
        );
        
        let (
            from_id,
            to_id,
            metadata,
            amount,
            receiver_payload
        ) = decode_payload(message_body);
        
        mint(amount, to_id, storage.stablecoin_contract);

        if metadata == 2 {
            let recipient: Result<ContractId, BridgeError> = match to_id {
                Identity::ContractId(contract_id) => Result::Ok(contract_id),
                _ => Result::Err(BridgeError::InvalidCallbackContract),
            };
            let receiver = abi(BridgeReceiver, recipient.unwrap().value);
            receiver.yama_bridge_callback(
                origin,
                from_id,
                amount,
                receiver_payload
            );
        }

        log(RemoteTransferReceived {
            from_id: from_id,
            src_chain: origin,
            to_id: to_id,
            amount: amount
        });
    }

    #[storage(read, write)]
    fn set_decimals(chain: u32, decimals: u8) {
        verify_sender_allowed(storage.stablecoin_contract);
        storage.decimals.insert(chain, decimals);
    }

    #[storage(read, write)]
    fn set_bridge(chain: u32, bridge: b256) {
        verify_sender_allowed(storage.stablecoin_contract);
        storage.bridge_id.insert(chain, bridge);
        log(SetBridge {
            account: sender_id(),
            chain: chain,
            bridge: bridge
        })
    }

    #[storage(read, write)]
    fn set_alt_bridge(chain: u32, alt_bridge: b256, is_alt_bridge: bool) {
        verify_sender_allowed(storage.stablecoin_contract);
        storage.alt_bridge_id.insert((chain, alt_bridge), is_alt_bridge);
    }

    #[storage(read, write)]
    fn set_mailbox(mailbox: b256) {
        verify_sender_allowed(storage.stablecoin_contract);
        storage.mailbox = mailbox;
    }

    #[storage(read)]
    fn get_stablecoin_contract() -> b256 {
        storage.stablecoin_contract
    }

    #[storage(read)]
    fn get_mailbox() -> b256 {
        storage.mailbox
    }

    #[storage(read)]
    fn get_bridge_id(chain: u32) -> b256 {
        storage.bridge_id.get(chain).unwrap()
    }

    #[storage(read)]
    fn get_alt_bridge_id(chain: u32, alt_bridge: b256) -> bool {
        storage.alt_bridge_id.get((chain, alt_bridge)).unwrap_or(false)
    }

    #[storage(read)]
    fn get_decimals(chain: u32) -> u8 {
        storage.decimals.get(chain).unwrap()
    }
}

fn encode_payload(
    from_id: Identity,
    to_id: b256,
    metadata: u32,
    amount: u64,
    to_decimals: u8,
    receiver_payload: Vec<u8>
) -> Vec<u8> {
    let mut receiver_payload: Vec<u8> = receiver_payload;
    let receiver_payload: Bytes = Bytes::from_vec_u8(receiver_payload);
    let mut payload = Bytes::with_length(
        RECEIVER_PAYLOAD_OFFSET + receiver_payload.len());

    let from_b256: b256 = match from_id {
        Identity::Address(addr) => addr.into(),
        Identity::ContractId(contract_id) => contract_id.into(),
    };
    let amount_u256 = U256::from((0, 0, 0, amount));
    let converted_amount = convert_amount_u256(
        amount_u256, DECIMALS, to_decimals
    );
    payload.write_u8(VERSION_OFFSET, 1);
    payload.write_b256(FROM_ID_OFFSET, from_b256);
    payload.write_b256(TO_ID_OFFSET, to_id);
    payload.write_u32(METADATA_OFFSET, metadata);

    payload.write_u64(AMOUNT_OFFSET, converted_amount.a);
    payload.write_u64(AMOUNT_OFFSET + 8, converted_amount.b);
    payload.write_u64(AMOUNT_OFFSET + 16, converted_amount.c);
    payload.write_u64(AMOUNT_OFFSET + 24, converted_amount.d);

    if receiver_payload.len() > 0 {
        payload.write_bytes(RECEIVER_PAYLOAD_OFFSET, receiver_payload);
    }
    payload.into_vec_u8()
}

fn decode_payload(
    payload: Vec<u8>
) -> (b256, Identity, u32, u64, Vec<u8>) {
    let mut payload: Vec<u8> = payload;
    let payload: Bytes = Bytes::from_vec_u8(payload);
    let from_id: b256 = payload.read_b256(FROM_ID_OFFSET);
    let to_bytes: b256 = payload.read_b256(TO_ID_OFFSET);
    let metadata: u32 = payload.read_u32(METADATA_OFFSET);
    // 0: Address
    // 1: ContractId
    // 2: ContractId and callback
    let to_id_result: Result<Identity, BridgeError> = match metadata {
        0 => Result::Ok(Identity::Address(Address::from(to_bytes))),
        1 => Result::Ok(Identity::ContractId(ContractId::from(to_bytes))),
        2 => Result::Ok(Identity::ContractId(ContractId::from(to_bytes))),
        _ => Result::Err(BridgeError::InvalidMetadata),
    };
    let to_id: Identity = to_id_result.unwrap();
    let amount: U256 = U256::from((
        payload.read_u64(AMOUNT_OFFSET),
        payload.read_u64(AMOUNT_OFFSET + 8),
        payload.read_u64(AMOUNT_OFFSET + 16),
        payload.read_u64(AMOUNT_OFFSET + 24)
    ));
    if payload.len() == RECEIVER_PAYLOAD_OFFSET {
        return (from_id, to_id, metadata, amount.d, Vec::new());
    }
    let receiver_payload: Bytes = payload.read_bytes(
        RECEIVER_PAYLOAD_OFFSET, payload.len() - RECEIVER_PAYLOAD_OFFSET);
    (from_id, to_id, metadata, amount.d, receiver_payload.into_vec_u8())
}


#[test]
fn test_encode_decode() {
    let from_id: Identity = Identity::Address(Address::from(
        0x0000000000000000000000000000000000000000000000000000000000000053));
    let to_id: b256
        = 0x0000000000000000000000000000000000000000000000000000000000000028;
    let metadata: u32 = 1;
    let amount: u64 = 4031491341337;
    let mut receiver_payload = Bytes::with_length(8);
    receiver_payload.write_u32(0, 4143);
    receiver_payload.write_u32(4, 1234);

    let encoded: Bytes = encode_payload(
        from_id, to_id, metadata, amount, 5, receiver_payload);

    let decoded: (b256, Identity, u32, u64, Bytes) = decode_payload(encoded);

    assert(Identity::Address(Address::from(decoded.0)) == from_id);
    assert(decoded.1 == Identity::ContractId(ContractId::from(to_id)));
    assert(decoded.2 == metadata);
    assert(decoded.3 == amount);
    assert(decoded.4 == receiver_payload);
}