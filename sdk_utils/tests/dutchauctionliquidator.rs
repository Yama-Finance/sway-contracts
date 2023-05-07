use fuels::{prelude::*, tx::ContractId};

use sdk_utils::{
  modulartoken::{
    mint,
    get_aid
  },
  cdp::{
    get_collateral_amount
  },
  dutchauctionliquidator::{
    get_price, is_expired, get_default_c_type_params,
    claim, get_collateral_amount_of_auction, reset_auction
  },
  abigen::*,
  utils::{
    get_timestamp,
    test_deploy,
    setup_test_and_liquidate,
    fp_to_u64
  }, psmpricesource
};

use std::time::Duration;
use async_std::task;

#[tokio::test]
async fn test_collateral_amount() {
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
  ) = setup_test_and_liquidate().await;

  let default_c_type_params
    = get_default_c_type_params(&dutchauctionliquidator).await;

  let collateral_amount = get_collateral_amount_of_auction(
    &dutchauctionliquidator,
    cdp.get_contract_id(),
    0
  ).await;

  assert_eq!(
    collateral_amount,
    150
  );

  assert_eq!(
    collateral_amount,
    get_collateral_amount(&cdp, 0).await
  );

  assert_eq!(
    wallet.get_provider().unwrap()
      .get_contract_asset_balance(cdp.get_contract_id(), get_aid(&collat_i))
      .await.unwrap(),
    collateral_amount
  );

}

#[tokio::test]
#[should_panic]
async fn test_underpay() {
  let (
    dutchauctionliquidator,
    _wallet,
    stable_i,
    _collat_i,
    _psm,
    psm_lockup,
    balancesheet,
    simplebsh,
    cdp,
    _price_source
  ) = setup_test_and_liquidate().await;

  let price = get_price(
    &dutchauctionliquidator,
    cdp.get_contract_id(),
    0
  ).await;

  claim(
    &dutchauctionliquidator,
    cdp.get_contract_id(),
    stable_i.get_contract_id(),
    balancesheet.get_contract_id(),
    simplebsh.get_contract_id(),
    psm_lockup.get_contract_id(),
    0,
    price - 1
  ).await;
}

#[tokio::test]
async fn test_claim_auction() {
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
  ) = setup_test_and_liquidate().await;

    let price = get_price(
        &dutchauctionliquidator,
        cdp.get_contract_id(),
        0
    ).await;

    assert_eq!(
      price,
      225
    );

    assert_eq!(
      is_expired(
        &dutchauctionliquidator,
        cdp.get_contract_id(),
        0
      ).await,
      false
    );



    task::sleep(Duration::from_secs(1)).await;

    let second_price = get_price(
        &dutchauctionliquidator,
        cdp.get_contract_id(),
        0
    ).await;

    assert!(second_price < price);

    mint(&stable_i, &wallet, second_price).await;


    claim(
      &dutchauctionliquidator,
      cdp.get_contract_id(),
      stable_i.get_contract_id(),
      balancesheet.get_contract_id(),
      simplebsh.get_contract_id(),
      psm_lockup.get_contract_id(),
      0,
      second_price
    ).await;

    assert_eq!(
      wallet.get_asset_balance(&get_aid(&collat_i)).await.unwrap(),
      150
    );

}

#[tokio::test]
#[should_panic]
async fn test_claim_expired_auction() {
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
  ) = setup_test_and_liquidate().await;

  let price = get_price(
    &dutchauctionliquidator,
    cdp.get_contract_id(),
    0
  ).await;

  assert_eq!(
    price,
    225
  );

  assert_eq!(
    is_expired(
      &dutchauctionliquidator,
      cdp.get_contract_id(),
      0
    ).await,
    false
  );

  task::sleep(Duration::from_secs(3)).await;

  let second_price = get_price(
    &dutchauctionliquidator,
    cdp.get_contract_id(),
    0
  ).await;

  assert!(second_price < price);

  mint(&stable_i, &wallet, second_price).await;

  assert_eq!(
    is_expired(
      &dutchauctionliquidator,
      cdp.get_contract_id(),
      0
    ).await,
    true
  );

  claim(
    &dutchauctionliquidator,
    cdp.get_contract_id(),
    stable_i.get_contract_id(),
    balancesheet.get_contract_id(),
    simplebsh.get_contract_id(),
    psm_lockup.get_contract_id(),
    0,
    second_price
  ).await;
}

#[tokio::test]
async fn test_reset_expired_auction() {
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
  ) = setup_test_and_liquidate().await;

  assert_eq!(
    is_expired(
      &dutchauctionliquidator,
      cdp.get_contract_id(),
      0
    ).await,
    false
  );

  task::sleep(Duration::from_secs(3)).await;

  assert_eq!(
    is_expired(
      &dutchauctionliquidator,
      cdp.get_contract_id(),
      0
    ).await,
    true
  );

  reset_auction(
    &dutchauctionliquidator,
    cdp.get_contract_id(),
    price_source.get_contract_id(),
    stable_i.get_contract_id(),
    balancesheet.get_contract_id(),
    simplebsh.get_contract_id(),
    psm_lockup.get_contract_id(),
    0
  ).await;

  assert_eq!(
    is_expired(
      &dutchauctionliquidator,
      cdp.get_contract_id(),
      1
    ).await,
    false
  );


}

#[tokio::test]
#[should_panic]
async fn test_premature_reset() {
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
  ) = setup_test_and_liquidate().await;

  assert_eq!(
    is_expired(
      &dutchauctionliquidator,
      cdp.get_contract_id(),
      0
    ).await,
    false
  );

  reset_auction(
    &dutchauctionliquidator,
    price_source.get_contract_id(),
    cdp.get_contract_id(),
    stable_i.get_contract_id(),
    balancesheet.get_contract_id(),
    simplebsh.get_contract_id(),
    psm_lockup.get_contract_id(),
    0
  ).await;
}