use tokio::sync::Mutex;
use lazy_static::lazy_static;
use fuels::{
    prelude::*,
};
use crate::{
    abigen::*,
    utils::set_storage_val,
    modulartoken::get_cid
};

lazy_static! {
    static ref MUTEX: Mutex<i32> = Mutex::new(0i32);
}

pub async fn init_custom_testswapper(
    wallet: &WalletUnlocked,
    stable_i: &ModularToken,
    collat_i: &ModularToken,
) -> TestSwapper {
    let storage_path = "../testswapper/out/debug/testswapper-storage_slots.json";

    let guard = MUTEX.lock().await;

    set_storage_val(
        &storage_path,
        "storage_0",
        &get_cid(stable_i).to_string()
    );

    set_storage_val(
        &storage_path,
        "storage_1",
        &get_cid(collat_i).to_string()
    );

    let id = Contract::deploy(
        "../testswapper/out/debug/testswapper.bin",
        &wallet,
        TxParameters::default(),
        StorageConfiguration::with_storage_path(Some(
            storage_path.to_string()
        ))
    )
    .await
    .unwrap();

    drop(guard);

    TestSwapper::new(id, wallet.clone())
}