use tokio::sync::Mutex;
use lazy_static::lazy_static;
use fuels::{prelude::*, tx::ContractId, types::{
  Identity,
  Bits256
}};
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

// Must set liquidator after init
pub async fn init_custom_cdp(
  wallet: &WalletUnlocked,
  stable_i: &ModularToken,
  collateral_manager: &ContractId,
  balancesheet_module: &ContractId,
) -> CDP {
  let storage_path = "../cdpmodule/out/debug/cdpmodule-storage_slots.json";

  let guard = MUTEX.lock().await;

  // Create a Mutex to synchronize access to the storage slots
  set_storage_val(
    &storage_path,
    "storage_0",
    &collateral_manager.to_string()
  );
  set_storage_val(
    &storage_path,
    "storage_2",
    &get_cid(stable_i).to_string()
  );
  set_storage_val(
    &storage_path,
    "storage_3",
    &balancesheet_module.to_string()
  );
  let id = Contract::deploy(
    "../cdpmodule/out/debug/cdpmodule.bin",
    &wallet,
    TxParameters::default(),
    StorageConfiguration::with_storage_path(Some(
      storage_path.to_string()
    ))
  )
  .await
  .unwrap();
  drop(guard);
  let instance: CDP = CDP::new(id.clone(), wallet.clone());
  set_allowlist(&stable_i, Identity::ContractId(id.clone().into()),
    true).await;
  instance
}

pub async fn set_liquidator(
  instance: &CDP,
  stable_id: &ContractId,
  liquidator: &ContractId
) {
  instance
    .methods()
    .set_liquidator(Bits256(*liquidator.clone()))
    .set_contract_ids(&[Bech32ContractId::from(*stable_id)])
    .call()
    .await
    .unwrap();
}

pub async fn add_collateral_type(
  instance: &CDP,
  stable_id: &ContractId,
  token: &ContractId,
  price_source: &ContractId,
  debt_floor: UFP128,
  debt_ceiling: UFP128,
  collateral_ratio: UFP128,
  interest_rate: UFP128,
  borrowing_enabled: bool,
  allowlist_enabled: bool,
) -> u64 {
  instance
    .methods()
    .add_collateral_type(
      Bits256::from_hex_str(&*token.to_string()).unwrap(),
      Bits256::from_hex_str(&*price_source.to_string()).unwrap(),
      debt_floor,
      debt_ceiling,
      collateral_ratio,
      interest_rate,
      borrowing_enabled,
      allowlist_enabled,
    )
    .set_contract_ids(&[Bech32ContractId::from(*stable_id)])
    .call()
    .await
    .unwrap()
    .value
}

pub async fn get_collateral_manager(
  instance: &CDP,
) -> Bech32ContractId {
  let bits = instance
    .methods()
    .get_collateral_manager()
    .simulate()
    .await
    .unwrap()
    .value;
  let cid = ContractId::new(bits.0);
  Bech32ContractId::from(cid)
}

pub async fn create_vault(
  instance: &CDP,
  collateral_type_id: u64,
  collateral: &AssetId,
  collateral_amount: u64,
  alt_owner: Option<Identity>,
) -> u64 {
  
  let tx_params = TxParameters::new(
    None, Some(1_010_000), None);

  instance
    .methods()
    .create_vault(
      collateral_type_id,
      alt_owner
    )
    .call_params(CallParameters::new(
      Some(collateral_amount),
      Some(collateral.clone()),
      None,
    ))
    .append_variable_outputs(1)
    .set_contract_ids(&[get_collateral_manager(instance).await])
    .tx_params(tx_params)
    .call()
    .await
    .unwrap()
    .value
}

pub async fn liquidate(
  instance: &CDP,
  stable_i: &Bech32ContractId,
  liquidator: &Bech32ContractId,
  price_source: &Bech32ContractId,
  balancesheet: &Bech32ContractId,
  bsh: &Bech32ContractId,
  bsh_target: &Bech32ContractId,
  vault_id: u64
) {
  let tx_params = TxParameters::new(
    None, Some(4_000_000), None);

  instance
    .methods()
    .liquidate(vault_id)
    .set_contract_ids(&[
      instance.get_contract_id().clone(),
      stable_i.clone(),
      liquidator.clone(),
      price_source.clone(),
      balancesheet.clone(),
      bsh.clone(),
      bsh_target.clone()
    ])
    .tx_params(tx_params)
    .call()
    .await
    .unwrap();
}

pub async fn update_interest(
  instance: &CDP,
  stable_id: &Bech32ContractId,
  price_source: &Bech32ContractId,
  balancesheet: &Bech32ContractId,
  bsh: &Bech32ContractId,
  bsh_target: &Bech32ContractId,
  collateral_type_id: u64
) {
  let tx_params = TxParameters::new(
    None, Some(32_000_000), None);

  instance
    .methods()
    .update_interest(collateral_type_id)
    .set_contract_ids(&[
      stable_id.clone(),
      price_source.clone(),
      balancesheet.clone(),
      bsh.clone(),
      bsh_target.clone()
    ])
    .tx_params(tx_params)
    .call()
    .await
    .unwrap();
}

pub async fn borrow(
  instance: &CDP,
  vault_id: u64,
  stable_id: &Bech32ContractId,
  price_source: &Bech32ContractId,
  balancesheet: &Bech32ContractId,
  bsh: &Bech32ContractId,
  bsh_target: &Bech32ContractId,
  amount: u64,
) {
  let tx_params = TxParameters::new(
    None, Some(32_000_000), None);
  
  instance
    .methods()
    .borrow(vault_id, amount)
    .set_contract_ids(&[
      price_source.clone(),
      balancesheet.clone(),
      stable_id.clone(),
      bsh.clone(),
      bsh_target.clone()
    ])
    .append_variable_outputs(1)
    .tx_params(tx_params)
    .call()
    .await
    .unwrap();
}

pub async fn repay(
  instance: &CDP,
  vault_id: u64,
  stable_id: &Bech32ContractId,
  price_source: &Bech32ContractId,
  balancesheet: &Bech32ContractId,
  bsh: &Bech32ContractId,
  bsh_target: &Bech32ContractId,
  amount: u64,
) {
  let tx_params = TxParameters::new(
    None, Some(32_000_000), None);
  
  instance
    .methods()
    .repay(vault_id)
    .set_contract_ids(&[
      price_source.clone(),
      balancesheet.clone(),
      stable_id.clone(),
      bsh.clone(),
      bsh_target.clone()
    ])
    .call_params(CallParameters::new(
      Some(amount),
      Some(AssetId::new(*ContractId::from(stable_id.clone()))),
      None,
    ))
    .append_variable_outputs(1)
    .tx_params(tx_params)
    .call()
    .await
    .unwrap();
}

pub async fn remove_collateral(
  instance: &CDP,
  vault_id: u64,
  collat_id: &Bech32ContractId,
  stable_id: &Bech32ContractId,
  price_source: &Bech32ContractId,
  balancesheet: &Bech32ContractId,
  bsh: &Bech32ContractId,
  bsh_target: &Bech32ContractId,
  amount: u64,
) {
  let tx_params = TxParameters::new(
    None, Some(32_000_000), None);
  
  instance
    .methods()
    .remove_collateral(vault_id, amount)
    .set_contract_ids(&[
      price_source.clone(),
      balancesheet.clone(),
      collat_id.clone(),
      stable_id.clone(),
      bsh.clone(),
      bsh_target.clone(),
      get_collateral_manager(instance).await
    ])
    .append_variable_outputs(1)
    .tx_params(tx_params)
    .call()
    .await
    .unwrap();
}

pub async fn get_collateral_value(
  instance: &CDP, vault_id: u64
) -> u64 {
  instance
    .methods()
    .get_collateral_value(vault_id)
    .simulate()
    .await
    .unwrap()
    .value
}

pub async fn get_debt(
  instance: &CDP, vault_id: u64
) -> u64 {
  instance
    .methods()
    .get_debt(vault_id)
    .simulate()
    .await
    .unwrap()
    .value
}

pub async fn get_target_collateral_value(
  instance: &CDP, vault_id: u64
) -> u64 {
  instance
    .methods()
    .get_target_collateral_value(vault_id)
    .simulate()
    .await
    .unwrap()
    .value
}

pub async fn get_collateral_amount(
  instance: &CDP, vault_id: u64
) -> u64 {
  instance
    .methods()
    .get_collateral_amount(vault_id)
    .simulate()
    .await
    .unwrap()
    .value
}