use tokio::sync::Mutex;
use lazy_static::lazy_static;
use fuels::{
    prelude::*,
    types::Identity
};
use crate::{
    utils::{
        set_storage_val,
        get_storage_val,
        get_test_wallet,
        int_to_hex,
        u64_to_fp,
        u128_to_fp
    },
    modulartoken::{
        set_allowlist,
        get_cid
    },
    abigen::*
};

lazy_static! {
    static ref MUTEX: Mutex<i32> = Mutex::new(0i32);
}

pub async fn init_custom_simplebsh(
    wallet: &WalletUnlocked,
    stable_i: &ModularToken,
    balancesheet_module: &ContractId,
    target: &ContractId
) -> SimpleBSH {
    let storage_path = "../simplebsh/out/debug/simplebsh-storage_slots.json";

    let guard = MUTEX.lock().await;

    set_storage_val(
        &storage_path,
        "storage_0",
        &get_cid(stable_i).to_string()
    );

    set_storage_val(
        &storage_path,
        "storage_1",
        &balancesheet_module.to_string()
    );

    set_storage_val(
        &storage_path,
        "storage_2",
        &target.to_string()
    );

    let id = Contract::deploy(
        "../simplebsh/out/debug/simplebsh.bin",
        &wallet,
        TxParameters::default(),
        StorageConfiguration::with_storage_path(Some(
            storage_path.to_string()
        ))
    ).await.unwrap();

    drop(guard);

    let simplebsh = SimpleBSH::new(id.clone(), wallet.clone());

    set_allowlist(
        &stable_i,
        Identity::ContractId(id.clone().into()),
        true
    ).await;

    simplebsh
}