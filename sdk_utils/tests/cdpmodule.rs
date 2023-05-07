use fuels::{prelude::*, tx::ContractId};

use sdk_utils::{
  modulartoken::{
    mint,
    get_aid
  },
  cdp::{
    create_vault,
    liquidate,
    get_debt,
    repay,
    remove_collateral,
    borrow, update_interest, get_target_collateral_value
  },
  abigen::*, utils::{
    get_timestamp,
    test_deploy
  }
};

use std::time::Duration;
use async_std::task;

#[tokio::test]
async fn test_create_vault() {
  let (
    _dutchauctionliquidator,
    wallet,
    _stable_i,
    collat_i,
    _psm,
    _psm_lockup,
    _balancesheet,
    _simplebsh,
    cdp,
    _price_source
  ) = test_deploy().await;
  
  let collat_amount: u64 = 150;

  mint(&collat_i, &wallet, collat_amount).await;
  create_vault(
    &cdp,
    0,
    &get_aid(&collat_i),
    collat_amount,
    None
  ).await;
}

#[tokio::test]
#[should_panic]
async fn test_bad_liquidation() {
  let (
    dutchauctionliquidator,
    wallet,
    stable_i,
    collat_i,
    _psm,
    psm_lockup,
    balancesheet,
    simplebsh,
    cdp,
    price_source
  ) = test_deploy().await;
  
  let collat_amount: u64 = 150;

  mint(&collat_i, &wallet, collat_amount).await;
  let vault_id = create_vault(
    &cdp,
    0,
    &get_aid(&collat_i),
    collat_amount,
    None
  ).await;

  liquidate(
    &cdp,
    stable_i.get_contract_id(),
    dutchauctionliquidator.get_contract_id(),
    price_source.get_contract_id(),
    balancesheet.get_contract_id(),
    simplebsh.get_contract_id(),
    psm_lockup.get_contract_id(),
    vault_id).await;
}

#[tokio::test]
async fn test_good_liquidation() {
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

  assert_eq!(
    wallet.get_asset_balance(&get_aid(&stable_i)).await.unwrap(),
    0
  );

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

  assert_eq!(
    wallet.get_asset_balance(&get_aid(&stable_i)).await.unwrap(),
    loan_amount
  );

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
  let target = get_target_collateral_value(
    &cdp, vault_id).await;
  println!("target: {}", target);

  liquidate(
    &cdp,
    stable_i.get_contract_id(),
    dutchauctionliquidator.get_contract_id(),
    price_source.get_contract_id(),
    balancesheet.get_contract_id(),
    simplebsh.get_contract_id(),
    psm_lockup.get_contract_id(),
    vault_id).await;

}

#[tokio::test]
async fn test_repay() {
  let (
    _dutchauctionliquidator,
    wallet,
    stable_i,
    collat_i,
    _psm,
    psm_lockup,
    balancesheet,
    simplebsh,
    cdp,
    price_source
  ) = test_deploy().await;
  
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

  assert_eq!(
    wallet.get_asset_balance(&get_aid(&stable_i)).await.unwrap(),
    0
  );

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

  assert_eq!(
    wallet.get_asset_balance(&get_aid(&stable_i)).await.unwrap(),
    loan_amount
  );

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

  let debt = get_debt(&cdp, vault_id).await;

  mint(&stable_i, &wallet, debt).await;

  repay(
    &cdp,
    vault_id,
    stable_i.get_contract_id(),
    price_source.get_contract_id(),
    balancesheet.get_contract_id(),
    simplebsh.get_contract_id(),
    psm_lockup.get_contract_id(),
    debt
  ).await;

  assert_eq!(
    wallet.get_asset_balance(&get_aid(&stable_i)).await.unwrap(),
    loan_amount
  );

  assert!(get_debt(&cdp, vault_id).await < debt);
}

#[tokio::test]
async fn test_remove_collateral() {
  let (
    _dutchauctionliquidator,
    wallet,
    stable_i,
    collat_i,
    _psm,
    psm_lockup,
    balancesheet,
    simplebsh,
    cdp,
    price_source
  ) = test_deploy().await;
  
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

  let collat_balance = wallet.get_asset_balance(&get_aid(&collat_i)).await.unwrap();
  println!("collat_balance: {}", collat_balance);

  remove_collateral(
    &cdp,
    vault_id,
    collat_i.get_contract_id(),
    stable_i.get_contract_id(),
    price_source.get_contract_id(),
    balancesheet.get_contract_id(),
    simplebsh.get_contract_id(),
    psm_lockup.get_contract_id(),
    collat_amount
  ).await;

  assert_eq!(
    wallet.get_asset_balance(&get_aid(&collat_i)).await.unwrap(),
    collat_balance + collat_amount
  );
}