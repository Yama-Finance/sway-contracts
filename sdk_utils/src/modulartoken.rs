use fuels::{
    prelude::*,
    tx::ContractId,
    types::Identity
};
use crate::{
    utils::{get_test_wallet, set_storage_val},
    abigen::*
};
use rand::{
    RngCore,
    rngs::OsRng,
    prelude::{Rng, SeedableRng, StdRng}
};
use lazy_static::lazy_static;
use tokio::sync::Mutex;

lazy_static! {
    static ref MUTEX: Mutex<i32> = Mutex::new(0i32);
}

pub async fn init_modulartoken() -> (ModularToken, WalletUnlocked) {
    let wallet: WalletUnlocked = get_test_wallet().await;
    let instance: ModularToken = init_custom_modulartoken(&wallet).await;
    (
        instance,
        wallet
    )
}

pub async fn init_custom_modulartoken(
    wallet: &WalletUnlocked
) -> ModularToken {
    // Launch a local network and deploy the contract
    let mut seed = [0u8; 32];
    OsRng.fill_bytes(&mut seed);
    let mut rng = StdRng::from_seed(seed);
    let salt: [u8; 32] = rng.gen();

    // Find and set the value for sha256("storage_2_1") in the JSON
    let storage_path = "../modulartoken/out/debug/modulartoken-storage_slots.json";


    let guard = MUTEX.lock().await;
    set_storage_val(
        &storage_path,
        "storage_2_1",
        &wallet.address().hash().to_string()
    );

    let id = Contract::deploy_with_parameters(
        "../modulartoken/out/debug/modulartoken.bin",
        &wallet,
        TxParameters::default(),
        StorageConfiguration::with_storage_path(Some(
            storage_path.to_string()
        )),
        Salt::from(salt)
    )
    .await
    .unwrap();

    drop(guard);

    let instance = ModularToken::new(id.clone(), wallet.clone());
    
    init_allowlist(&instance).await;

    instance
}

pub async fn get_allowlist(instance: &ModularToken, id: Identity) -> bool {
    instance
        .methods()
        .get_allowlist(id)
        .call()
        .await
        .unwrap()
        .value
}

pub async fn mint(
  instance: &ModularToken,
  wallet: &WalletUnlocked,
  amount: u64
) {
  instance
      .methods()
      .mint(amount, Identity::Address(wallet.address().into()))
      .append_variable_outputs(1)
      .call()
      .await
      .unwrap();
}

pub async fn init_allowlist(
    instance: &ModularToken
) {
    instance
        .methods()
        .init_allowlist()
        .call()
        .await
        .unwrap();
}

pub async fn set_allowlist(
    instance: &ModularToken,
    id: Identity,
    value: bool
) {
    instance
        .methods()
        .set_allowlist(id, value)
        .call()
        .await
        .unwrap();
}

pub fn get_cid(contract: &ModularToken) -> ContractId {
    ContractId::from(contract.get_contract_id())
}

pub fn get_aid(contract: &ModularToken) -> AssetId {
    AssetId::from(*get_cid(contract))
}