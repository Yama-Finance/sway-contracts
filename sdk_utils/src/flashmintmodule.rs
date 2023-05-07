use fuels::prelude::*;
use crate::{
    abigen::*,
    utils::{
        get_test_wallet,
        set_storage_val
    },
    modulartoken::{
        get_cid,
        init_custom_modulartoken
    },
};
use tokio::sync::Mutex;
use lazy_static::lazy_static;

lazy_static! {
    static ref MUTEX: Mutex<i32> = Mutex::new(0i32);
}

pub async fn init_flashmintmodule() -> (
    WalletUnlocked,
    ModularToken,
    FlashMintModule
) {
    let wallet: WalletUnlocked = get_test_wallet().await;
    let stable_i: ModularToken
        = init_custom_modulartoken(&wallet).await;
    let flashmintmodule
        = init_custom_flashmintmodule(&wallet, &stable_i).await;

    (
        wallet,
        stable_i,
        flashmintmodule
    )
}

pub async fn init_custom_flashmintmodule(
    wallet: &WalletUnlocked,
    stable_i: &ModularToken
) -> FlashMintModule {
    let storage_path = "../flashmintmodule/out/debug/flashmintmodule-storage_slots.json";

    let guard = MUTEX.lock().await;

    set_storage_val(
        &storage_path,
        "storage_0",
        &get_cid(stable_i).to_string()
    );

    let id = Contract::deploy(
        "../flashmintmodule/out/debug/flashmintmodule.bin",
        &wallet,
        TxParameters::default(),
        StorageConfiguration::with_storage_path(Some(
            storage_path.to_string()
        ))
    )
    .await
    .unwrap();

    drop(guard);

    FlashMintModule::new(id, wallet.clone())
}