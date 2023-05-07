use fuels::prelude::*;
use crate::{
    utils::{
        set_storage_val,
        get_test_wallet
    },
    modulartoken::{
        get_cid,
        init_custom_modulartoken
    },
    psm::init_custom_psm,
    abigen::*,
};
use tokio::sync::Mutex;
use lazy_static::lazy_static;

lazy_static! {
    static ref MUTEX: Mutex<i32> = Mutex::new(0i32);
}

pub async fn init_custom_psmlockup(
    wallet: &WalletUnlocked,
    stable_i: &ModularToken,
    token: &ContractId,
    psm: &ContractId
) -> PSMLockup {
    let storage_path = "../psmlockup/out/debug/psmlockup-storage_slots.json";

    let guard = MUTEX.lock().await;

    set_storage_val(
        &storage_path,
        "storage_0",
        &get_cid(stable_i).to_string()
    );

    set_storage_val(
        &storage_path,
        "storage_1",
        &token.to_string()
    );

    set_storage_val(
        &storage_path,
        "storage_2",
        &psm.to_string()
    );

    let id = Contract::deploy(
        "../psmlockup/out/debug/psmlockup.bin",
        &wallet,
        TxParameters::default(),
        StorageConfiguration::with_storage_path(Some(
            storage_path.to_string()
        ))
    )
    .await
    .unwrap();

    PSMLockup::new(id, wallet.clone())
}

pub async fn init_psmlockup() -> (
    PSMLockup,
    WalletUnlocked,
    ModularToken,
    ModularToken,
    PSM
) {
    let wallet: WalletUnlocked = get_test_wallet().await;
    let stable_i: ModularToken = init_custom_modulartoken(&wallet).await;
    let collat_i: ModularToken = init_custom_modulartoken(&wallet).await;
    let psm = init_custom_psm(
        &wallet, &stable_i, &collat_i).await;
    let psmlockup = init_custom_psmlockup(
        &wallet, &stable_i, &get_cid(&collat_i),
        &ContractId::from(psm.get_contract_id())
    ).await;

    (
        psmlockup,
        wallet,
        stable_i,
        collat_i,
        psm
    )
}

pub async fn lockup(
    instance: &PSMLockup,
    psm: &Bech32ContractId,
    stable_i: &Bech32ContractId,
    token: &AssetId,
    amount: u64
) {
    let tx_params = TxParameters::new(
        None, Some(32_000_000), None);
    
    instance
        .methods()
        .lockup()
        .call_params(CallParameters::new(
            Some(amount),
            Some(token.clone()),
        None))
        .tx_params(tx_params)
        .append_variable_outputs(2)
        .set_contract_ids(
            &[stable_i.clone(),
            psm.clone(),
            Bech32ContractId::from(ContractId::from(*token.clone()))])
        .call()
        .await
        .unwrap();
}

pub async fn redeem(
    instance: &PSMLockup,
    psm: &Bech32ContractId,
    stable_i: &Bech32ContractId,
    amount: u64
) {
    let tx_params = TxParameters::new(
        None, Some(32_000_000), None);

    instance
        .methods()
        .redeem()
        .call_params(CallParameters::new(
            Some(amount),
            Some(AssetId::new(*ContractId::from(instance.get_contract_id()))),
        None))
        .tx_params(tx_params)
        .append_variable_outputs(2)
        .set_contract_ids(
            &[stable_i.clone(),
            psm.clone()])
        .call()
        .await
        .unwrap();
}

pub async fn value(
    instance: &PSMLockup,
    stable_i: &Bech32ContractId
) -> UFP128 {
    let tx_params: TxParameters = TxParameters::new(
        None, Some(32_000_000), None);

    let value = instance
        .methods()
        .value()
        .call_params(CallParameters::new(
            None,
            Some(AssetId::new(*ContractId::from(instance.get_contract_id()))),
        None))
        .tx_params(tx_params)
        .set_contract_ids(
            &[stable_i.clone()])
        .call()
        .await
        .unwrap()
        .value;

    value
}