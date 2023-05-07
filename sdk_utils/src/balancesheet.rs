use fuels::{prelude::*, tx::ContractId, types::{Identity, Bits256}};
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
  abigen::*, simplebsh::init_custom_simplebsh
};
use tokio::sync::Mutex;
use lazy_static::lazy_static;

lazy_static! {
    static ref MUTEX: Mutex<i32> = Mutex::new(0i32);
}

pub async fn init_balancesheet() -> (
  WalletUnlocked,
  ModularToken,
  BalanceSheet,
  SimpleBSH
) {
  let wallet: WalletUnlocked = get_test_wallet().await;
  let stable_i: ModularToken
    = init_custom_modulartoken(&wallet).await;
  let (
    balancesheet,
    simplebsh
  ) = init_custom_balancesheet(&wallet, &stable_i,
      &ContractId::from(stable_i.get_contract_id())).await;
  // Setting the stablecoin as the BSH target is kinda hacky but it's
  // convenient for testing

  (
    wallet,
    stable_i,
    balancesheet,
    simplebsh
  )
}

pub async fn init_custom_balancesheet(
  wallet: &WalletUnlocked,
  stable_i: &ModularToken,
  bsh_target: &ContractId
) -> (BalanceSheet, SimpleBSH)
{
  let storage_path = "../balancesheetmodule/out/debug/balancesheetmodule-storage_slots.json";

  let guard = MUTEX.lock().await;

  set_storage_val(
    &storage_path,
    "storage_0",
    &get_cid(stable_i).to_string()
  );

  let id = Contract::deploy(
    "../balancesheetmodule/out/debug/balancesheetmodule.bin",
    &wallet,
    TxParameters::default(),
    StorageConfiguration::with_storage_path(Some(
      storage_path.to_string()
    ))
  )
  .await
  .unwrap();
  drop(guard);

  let instance = BalanceSheet::new(id.clone(), wallet.clone());

  set_allowlist(&stable_i, Identity::ContractId 
    (id.clone().into()), true).await;

  let simplebsh = init_custom_simplebsh(
    &wallet,
    &stable_i,
    &ContractId::from(id.clone()),
    &bsh_target
  ).await;

  set_handler(
    &instance,
    stable_i.get_contract_id(),
    &ContractId::from(simplebsh.id())
  ).await;

  (instance, simplebsh)
}

pub async fn set_handler(
  balancesheet: &BalanceSheet,
  stable_id: &Bech32ContractId,
  handler: &ContractId
) {
  balancesheet
    .methods()
    .set_handler(
      Bits256(*handler.clone()),
    )
    .set_contract_ids(&[
      stable_id.clone()
    ])
    .call()
    .await
    .unwrap();
}

pub async fn add_surplus(
  balancesheet: &BalanceSheet,
  stable_id: &Bech32ContractId,
  simplebsh: &Bech32ContractId,
  bsh_target: &Bech32ContractId,
  amount: I256
) {
  let tx_params = TxParameters::new(
    None, Some(32_000_000), None);

  balancesheet
    .methods()
    .add_surplus(
      amount,
    )
    .set_contract_ids(&[
      stable_id.clone(),
      simplebsh.clone(),
      bsh_target.clone()
    ])
    .tx_params(tx_params)
    .call()
    .await
    .unwrap();
}

pub async fn add_deficit(
  balancesheet: &BalanceSheet,
  stable_id: &Bech32ContractId,
  simplebsh: &Bech32ContractId,
  bsh_target: &Bech32ContractId,
  amount: I256
) {
  let tx_params = TxParameters::new(
    None, Some(32_000_000), None);

  balancesheet
    .methods()
    .add_deficit(
      amount,
    )
    .set_contract_ids(&[
      stable_id.clone(),
      simplebsh.clone(),
      bsh_target.clone()
    ])
    .tx_params(tx_params)
    .call()
    .await
    .unwrap();
}

pub async fn set_surplus(
  balancesheet: &BalanceSheet,
  stable_id: &Bech32ContractId,
  amount: I256
) {
  let tx_params = TxParameters::new(
    None, Some(32_000_000), None);

  balancesheet
    .methods()
    .set_surplus(
      amount,
    )
    .set_contract_ids(&[
      stable_id.clone()
    ])
    .tx_params(tx_params)
    .call()
    .await
    .unwrap();
}

pub async fn total_surplus(
  balancesheet: &BalanceSheet,
  stable_id: &Bech32ContractId
) -> I256 {
  balancesheet
    .methods()
    .total_surplus()
    .set_contract_ids(&[
      stable_id.clone()
    ])
    .call()
    .await
    .unwrap()
    .value
}