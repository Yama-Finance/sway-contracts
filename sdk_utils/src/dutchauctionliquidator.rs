use tokio::sync::Mutex;
use lazy_static::lazy_static;
use fuels::{prelude::*, tx::ContractId, types::Identity};
use crate::{
  utils::{
      set_storage_val,
      int_to_hex,
  },
  modulartoken::{
      set_allowlist,
      get_cid
  },
  cdp::{
    set_liquidator,
  },
  abigen::*,
};

lazy_static! {
  static ref MUTEX: Mutex<i32> = Mutex::new(0i32);
}

pub async fn init_custom_dutchauctionliquidator(
  wallet: &WalletUnlocked,
  stable_i: &ModularToken,
  balancesheet: &ContractId,
  cdp: &CDP,
  default_initial_price_ratio: &UFP128,
  default_time_interval: u64,
  default_change_rate: &UFP128,
  default_reset_threshold: u64
) -> DutchAuctionLiquidator
{
  let storage_path = "../dutchauctionliquidator/out/debug/dutchauctionliquidator-storage_slots.json";
  let guard = MUTEX.lock().await;
  set_storage_val(
    &storage_path,
    "storage_0",
    &get_cid(&stable_i).to_string()
  );
  set_storage_val(
    &storage_path,
    "storage_1",
    &balancesheet.to_string()
  );
  set_storage_val(
    &storage_path,
    "storage_2",
    &ContractId::from(cdp.get_contract_id()).to_string()
  );

  write_fp(
    &storage_path,
    "storage_3_0",
    &default_initial_price_ratio
  );

  set_storage_val(
    &storage_path,
    "storage_3_1",
    &int_to_hex(default_time_interval)
  );
  
  write_fp(
    &storage_path,
    "storage_3_2",
    &default_change_rate
  );

  set_storage_val(
    &storage_path,
    "storage_3_3",
    &int_to_hex(default_reset_threshold)
  );

  let id = Contract::deploy(
    "../dutchauctionliquidator/out/debug/dutchauctionliquidator.bin",
    &wallet,
    TxParameters::default(),
    StorageConfiguration::with_storage_path(Some(
      storage_path.to_string()
    ))
  )
  .await
  .unwrap();

  drop(guard);
  
  let instance = DutchAuctionLiquidator::new(id.clone(), wallet.clone());

  set_allowlist(&stable_i, Identity::ContractId 
    (id.clone().into()), true).await;
  

  set_liquidator(
    &cdp,
    &get_cid(&stable_i),
    &ContractId::from(id)
  ).await;
  
  instance
}

pub fn write_fp(
  json_file_path: &str,
  key: &str,
  value: &UFP128
) {
  set_storage_val(
    json_file_path,
    &format!("{}_0_0", key),
    &int_to_hex(value.value.upper)
  );
  set_storage_val(
    json_file_path,
    &format!("{}_0_1", key),
    &int_to_hex(value.value.lower)
  );
}

pub async fn get_price(
  instance: &DutchAuctionLiquidator,
  cdp: &Bech32ContractId,
  auction_id: u64,
) -> u64 {
  instance
    .methods()
    .get_price(
      auction_id
    )
    .set_contract_ids(&[
      cdp.clone(),
    ])
    .simulate()
    .await
    .unwrap()
    .value
}

pub async fn is_expired(
  instance: &DutchAuctionLiquidator,
  cdp: &Bech32ContractId,
  auction_id: u64,
) -> bool {
  instance
    .methods()
    .is_expired(
      auction_id
    )
    .set_contract_ids(&[
      cdp.clone(),
    ])
    .simulate()
    .await
    .unwrap()
    .value
}

pub async fn get_collateral_amount_of_auction(
  instance: &DutchAuctionLiquidator,
  cdp: &Bech32ContractId,
  auction_id: u64,
) -> u64 {
  instance
    .methods()
    .get_collateral_amount_of_auction(
      auction_id
    )
    .set_contract_ids(&[
      cdp.clone(),
    ])
    .simulate()
    .await
    .unwrap()
    .value
}

pub async fn get_default_c_type_params(
  instance: &DutchAuctionLiquidator
) -> CTypeParams {
  instance
    .methods()
    .get_default_c_type_params()
    .simulate()
    .await
    .unwrap()
    .value
}

pub async fn claim(
  instance: &DutchAuctionLiquidator,
  cdp: &Bech32ContractId,
  stable_i: &Bech32ContractId,
  balancesheet: &Bech32ContractId,
  bsh: &Bech32ContractId,
  bsh_target: &Bech32ContractId,
  auction_id: u64,
  amount: u64,
) {
  let call_params = CallParameters::new(
    Some(amount),
    Some(AssetId::new(*ContractId::from(stable_i.clone()))),
    None
  );

  let tx_params = TxParameters::new(
    None, Some(32_000_000), None);

  instance
    .methods()
    .claim(
      auction_id
    )
    .set_contract_ids(&[
      cdp.clone(),
      stable_i.clone(),
      balancesheet.clone(),
      bsh.clone(),
      bsh_target.clone(),
    ])
    .append_variable_outputs(2)
    .call_params(call_params)
    .tx_params(tx_params)
    .call()
    .await
    .unwrap();
}

pub async fn reset_auction(
  instance: &DutchAuctionLiquidator,
  cdp: &Bech32ContractId,
  price_source: &Bech32ContractId,
  stable_i: &Bech32ContractId,
  balancesheet: &Bech32ContractId,
  bsh: &Bech32ContractId,
  bsh_target: &Bech32ContractId,
  auction_id: u64,
) {
  let tx_params = TxParameters::new(
    None, Some(32_000_000), None);

  instance
    .methods()
    .reset_auction(
      auction_id
    )
    .set_contract_ids(&[
      cdp.clone(),
      price_source.clone(),
      stable_i.clone(),
      balancesheet.clone(),
      bsh.clone(),
      bsh_target.clone(),
    ])
    .tx_params(tx_params)
    .call()
    .await
    .unwrap();
}