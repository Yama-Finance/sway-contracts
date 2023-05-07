use tokio::sync::Mutex;
use lazy_static::lazy_static;
use fuels::{prelude::*, tx::ContractId, types::Identity};
use crate::{
  utils::{
      set_storage_val,
      get_storage_val,
      get_test_wallet
  },
  modulartoken::{
      init_custom_modulartoken,
      set_allowlist,
      get_cid
  },
  abigen::*
};

lazy_static! {
    static ref MUTEX: Mutex<i32> = Mutex::new(0i32);
}

pub async fn init_psm() -> (
    PSM,
    WalletUnlocked,
    ModularToken,
    ModularToken,
) {
    let wallet: WalletUnlocked = get_test_wallet().await;
    let stable_i: ModularToken
        = init_custom_modulartoken(&wallet).await;
    let ext_i: ModularToken
        = init_custom_modulartoken(&wallet).await;
    let psm: PSM = init_custom_psm(&wallet, &stable_i, &ext_i).await;

    (
        psm,
        wallet,
        stable_i,
        ext_i,
    )
}

pub async fn init_custom_psm(
    wallet: &WalletUnlocked,
    stable_i: &ModularToken,
    ext_i: &ModularToken
) -> PSM {
    let storage_path = "../pegstabilitymodule/out/debug/pegstabilitymodule-storage_slots.json";
    
    let guard = MUTEX.lock().await;

    // Create a Mutex to synchronize access to the storage slots
    set_storage_val(
        &storage_path,
        "storage_0",
        &get_cid(&stable_i).to_string()
    );

    set_storage_val(
        &storage_path,
        "storage_1",
        &get_cid(&ext_i).to_string()
    );

    let id = Contract::deploy(
        "../pegstabilitymodule/out/debug/pegstabilitymodule.bin",
        &wallet,
        TxParameters::default(),
        StorageConfiguration::with_storage_path(Some(
            storage_path.to_string()
        )),
    )
    .await
    .unwrap();

    assert_eq!(
        get_storage_val(&storage_path, "storage_0").unwrap(),
        get_cid(&stable_i).to_string()
    );
    assert_eq!(
        get_storage_val(&storage_path, "storage_1").unwrap(),
        get_cid(&ext_i).to_string()
    );

    drop(guard);


    let instance = PSM::new(id.clone(), wallet.clone());
    set_allowlist(&stable_i, Identity::ContractId(id.clone().into()), true)
        .await;

    instance
}
pub async fn deposit(
    instance: &PSM, stable_id: &ContractId, ext: &AssetId, amount: u64
) {
    instance
        .methods()
        .deposit()
        .call_params(CallParameters::new(
            Some(amount),
            Some(ext.clone()),
            None))
        .append_variable_outputs(1)
        .set_contract_ids(&[Bech32ContractId::from(*stable_id)])
        .call()
        .await
        .unwrap();
}


pub async fn withdraw(
    instance: &PSM,
    stable_id: &ContractId,
    stablecoin: &AssetId,
    amount: u64
) {
    instance
        .methods()
        .withdraw()
        .call_params(CallParameters::new(
            Some(amount),
            Some(stablecoin.clone()),
            None))
        .append_variable_outputs(1)
        .set_contract_ids(&[Bech32ContractId::from(*stable_id)])
        .call()
        .await
        .unwrap();
}