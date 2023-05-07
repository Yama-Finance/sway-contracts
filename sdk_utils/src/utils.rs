use serde_json::Value;
use sha2::{Sha256, Digest};
use std::io::Write;
use fuels::{
  signers::fuel_crypto::SecretKey,
  prelude::*,
  prelude::Error,
  types::{
    Identity,
    block::Block
  },
  client::{
    PaginationRequest,
    PageDirection
  },
};
use crate::{
  modulartoken::{
      init_custom_modulartoken,
      set_allowlist,
      get_cid,
      mint,
      get_aid
  },
  balancesheet::{
    init_custom_balancesheet
  },
  cdp::{
    init_custom_cdp,
    set_liquidator,
    add_collateral_type,
    create_vault,
    borrow,
    liquidate,
    update_interest
  },
  emptycollateralmanager::{
    init_emptycollateralmanager
  },
  dutchauctionliquidator::{
    init_custom_dutchauctionliquidator
  },
  psmpricesource::{init_psmpricesource},
  abigen::*, psm::init_custom_psm, psmlockup::init_custom_psmlockup
};
use std::time::Duration;
use async_std::task;

fn sha256(input: &str) -> String {
  let mut hasher = Sha256::new();
  hasher.update(input.as_bytes());
  let result = hasher.finalize();

  format!("{:x}", result)
}

pub async fn get_timestamp(provider: &Provider) -> Result<i64, Error> {
  let req = PaginationRequest {
    cursor: None,
    results: 1,
    direction: PageDirection::Backward,
  };
  let blocks: Vec<Block> = provider.get_blocks(req).await?.results;

  Ok(blocks[0].header.time.unwrap().timestamp())
}

pub async fn get_test_wallet() -> WalletUnlocked {
  let key = std::env::var("FUEL_TEST_KEY").expect("FUEL_TEST_KEY is not set.");
  let secret_key: SecretKey = key.parse().unwrap();
  let mut wallet = WalletUnlocked::new_from_private_key(secret_key, None);
  println!("The wallet address hash is {}", wallet.address().hash());
  
  let num_assets = 3;
  let coins_per_asset = 10;
  let amount_per_coin = 1_000_000;
  let (coins, _asset_ids) = setup_multiple_assets_coins(
      wallet.address(),
      num_assets,
      coins_per_asset,
      amount_per_coin,
  );

  let config = Config {
      manual_blocks_enabled: true, // Necessary so the `produce_blocks` API can be used locally
      ..Config::local_node()
  };

  let (provider, _socket_addr) = setup_test_provider(
      coins.clone(), vec![], Some(config), None).await;

  wallet.set_provider(provider);

  wallet
}

pub fn set_storage_val(json_file_path: &str, key: &str, value: &str) {
  let file_guard = std::fs::File::open(json_file_path).unwrap();
  let json_result = serde_json::from_reader(file_guard).unwrap();
  let mut json: Value = json_result;
  serde_json::to_string_pretty(&json).unwrap();

  let mut edited: bool = false;
  let mut found: bool = false;

  for obj in json.as_array_mut().unwrap() {
      let key_value = obj["key"].as_str().unwrap();
      if key_value == &sha256(key) {
          let new_value = Value::String(value.to_string());
          if obj["value"] != new_value {
              obj["value"] = new_value;
              edited = true;
          }
          found = true;
          break;
      }
  }

  if !found {
    panic!("Storage key not found.");
  }
  if !edited {
    return;
  }

  let json_string = serde_json::to_string_pretty(&json).unwrap();

  let mut json_file_guard = std::fs::OpenOptions::new()
      .write(true)
      .create(true)
      .open(json_file_path)
      .unwrap();
  json_file_guard.write_all(json_string.as_bytes()).unwrap();
}

pub fn int_to_hex(num: u64) -> String {
  let suffix = "0".repeat(48);
  format!("{:016x}{}", num, suffix)
}


pub fn get_storage_val(json_file_path: &str, key: &str) -> Option<String> {
  let file_guard = std::fs::File::open(json_file_path).unwrap();
  let json_result = serde_json::from_reader(file_guard).unwrap();
  let json: Value = json_result;

  for obj in json.as_array().unwrap() {
      let key_value = obj["key"].as_str().unwrap();
      if key_value == &sha256(key) {
          let value = obj["value"].as_str().unwrap();
          return Some(value.to_string());
      }
  }

  return None;
}

pub fn get_id(wallet: &WalletUnlocked) -> Identity {
  let wallet_address = Address::new(*wallet.address().hash());
  Identity::Address(wallet_address)
}


pub fn u64_to_fp(value: u64) -> UFP128 {
  UFP128 {
    value: U128 { upper: value, lower: 0 }
  }
}

pub fn fp_to_u64(value: UFP128) -> u64 {
  value.value.upper
}

pub fn u128_to_fp(value: u128) -> UFP128 {
  let lower: u64 = (value as u64) & 0xffffffffffffffff;
  let upper: u64 = (value >> 64) as u64 & 0xffffffffffffffff;
  UFP128 {
    value: U128 { upper: upper, lower: lower }
  }
}


pub async fn test_deploy() -> (
  DutchAuctionLiquidator,
  WalletUnlocked,
  ModularToken,
  ModularToken,
  PSM,
  PSMLockup,
  BalanceSheet,
  SimpleBSH,
  CDP,
  PSMPriceSource
) {
  let wallet: WalletUnlocked = get_test_wallet().await;
  let stable_i: ModularToken
    = init_custom_modulartoken(&wallet).await;
  let collat_i: ModularToken
    = init_custom_modulartoken(&wallet).await;
  let psm = init_custom_psm(
    &wallet, &stable_i, &collat_i).await;
  let psm_lockup = init_custom_psmlockup(
    &wallet, &stable_i, &get_cid(&collat_i),
    &ContractId::from(psm.get_contract_id())).await;
  let (balancesheet, simplebsh) = init_custom_balancesheet(
    &wallet, &stable_i,
    &ContractId::from(psm_lockup.get_contract_id())
  ).await;
  
  let emptycollateralmanager = init_emptycollateralmanager(wallet.clone()).await;
  let cdp = init_custom_cdp(
    &wallet,
    &stable_i,
    &ContractId::from(emptycollateralmanager.get_contract_id()),
    &ContractId::from(balancesheet.get_contract_id()),
  ).await;

  let dutchauctionliquidator
    = init_custom_dutchauctionliquidator(
      &wallet,
      &stable_i,
      &ContractId::from(balancesheet.get_contract_id()),
      &cdp,
      &u128_to_fp(0b11 << 63), // 1.5
      1,
      &u128_to_fp(0b1 << 63), // 0.5
      3
    ).await;

  // Adding a new collateral type
  let price_source = init_psmpricesource(&wallet).await;
  add_collateral_type(
    &cdp,
    &get_cid(&stable_i),
    &get_cid(&collat_i),
    &ContractId::from(price_source.get_contract_id()),
    u64_to_fp(100),
    u64_to_fp(10000),
    u128_to_fp(0b11 << 63), // 1.5
    u64_to_fp(2),
    true,
    false
  ).await;
  
  (
    dutchauctionliquidator,
    wallet,
    stable_i,
    collat_i,
    psm,
    psm_lockup,
    balancesheet,
    simplebsh,
    cdp,
    price_source
  )
}


pub async fn setup_test_and_liquidate() -> (
  DutchAuctionLiquidator,
  WalletUnlocked,
  ModularToken,
  ModularToken,
  PSM,
  PSMLockup,
  BalanceSheet,
  SimpleBSH,
  CDP,
  PSMPriceSource
) {
  let (
      dutchauctionliquidator,
      wallet,
      stable_i,
      collat_i,
      psm,
      psm_lockup,
      balancesheet,
      simplebsh,
      cdp,
      price_source
  ) = test_deploy().await;

  // Print all the contract IDs
  println!("dutchauctionliquidator: {}",
    ContractId::from(dutchauctionliquidator.get_contract_id()));
  println!("stable_i: {}",
    ContractId::from(stable_i.get_contract_id()));
  println!("collat_i: {}",
    ContractId::from(collat_i.get_contract_id()));
  println!("balancesheet: {}",
    ContractId::from(balancesheet.get_contract_id()));
  println!("simplebsh: {}",
    ContractId::from(simplebsh.get_contract_id()));
  println!("cdp: {}",
    ContractId::from(cdp.get_contract_id()));
  println!("price_source: {}",
    ContractId::from(price_source.get_contract_id()));

  let collat_amount: u64 = 150;
  let loan_amount: u64 = 100;

  mint(&collat_i, &wallet, collat_amount).await;
  let vault_id = create_vault(
      &cdp,
      0,
      &get_aid(&collat_i),
      collat_amount,
      None
  ).await;

  borrow(
      &cdp,
      vault_id,
      stable_i.get_contract_id(),
      price_source.get_contract_id(),
      balancesheet.get_contract_id(),
      simplebsh.get_contract_id(),
      psm_lockup.get_contract_id(),
      loan_amount
  ).await;
  
  task::sleep(Duration::from_secs(1)).await;

  update_interest(
      &cdp,
      stable_i.get_contract_id(),
      price_source.get_contract_id(),
      balancesheet.get_contract_id(),
      simplebsh.get_contract_id(),
      psm_lockup.get_contract_id(),
      vault_id
  ).await;

  liquidate(
      &cdp,
      stable_i.get_contract_id(),
      dutchauctionliquidator.get_contract_id(),
      price_source.get_contract_id(),
      balancesheet.get_contract_id(),
      simplebsh.get_contract_id(),
      psm_lockup.get_contract_id(),
      vault_id
  ).await;

  (
      dutchauctionliquidator,
      wallet,
      stable_i,
      collat_i,
      psm,
      psm_lockup,
      balancesheet,
      simplebsh,
      cdp,
      price_source
  )
}


pub fn u64_to_i256(value: u64) -> I256 {
  I256 {
    underlying: U256 { a: 0, b: 1, c: 0, d: value }
  }
}

pub fn get_id_key(asset_id: &AssetId) -> String {
  format!("{asset_id:#x}")
}