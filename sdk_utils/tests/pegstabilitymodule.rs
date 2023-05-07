use sdk_utils::{
  psm::*,
  modulartoken::{
    mint,
    get_cid,
    get_aid
  }
};

#[tokio::test]
async fn deposit_test() {
  let (
      instance,
      wallet,
      stable_i,
      ext_i,
  ) = init_psm().await;

  let amount = 53;

  mint(&ext_i, &wallet, amount).await;

  assert_eq!(
      wallet.get_asset_balance(&get_aid(&stable_i)).await.unwrap(),
      0
  );
  assert_eq!(
      wallet.get_asset_balance(&get_aid(&ext_i)).await.unwrap(),
      amount
  );

  deposit(&instance, &get_cid(&stable_i), &get_aid(&ext_i), amount).await;


  assert_eq!(
      wallet.get_asset_balance(&get_aid(&stable_i)).await.unwrap(),
      amount
  );
  assert_eq!(
      wallet.get_asset_balance(&get_aid(&ext_i)).await.unwrap(),
      0
  );
}

#[tokio::test]
async fn withdraw_test() {
  let (
      instance,
      wallet,
      stable_i,
      ext_i,
  ) = init_psm().await;

  let amount = 53;

  mint(&ext_i, &wallet, amount).await;
  deposit(&instance, &get_cid(&stable_i), &get_aid(&ext_i), amount).await;

  assert_eq!(
      wallet.get_asset_balance(&get_aid(&stable_i)).await.unwrap(),
      amount
  );
  assert_eq!(
      wallet.get_asset_balance(&get_aid(&ext_i)).await.unwrap(),
      0
  );

  withdraw(&instance, &get_cid(&stable_i), &get_aid(&stable_i), 53).await;

  assert_eq!(
      wallet.get_asset_balance(&get_aid(&stable_i)).await.unwrap(),
      0
  );
  assert_eq!(
      wallet.get_asset_balance(&get_aid(&ext_i)).await.unwrap(),
      amount
  );
}

#[tokio::test]
#[should_panic]
async fn deposit_exceeds_debt_ceiling() {
  let (
      instance,
      wallet,
      stable_i,
      ext_i,
  ) = init_psm().await;

  let amount = u64::MAX / 2;

  mint(&ext_i, &wallet, amount).await;
  deposit(&instance, &get_cid(&stable_i), &get_aid(&ext_i), amount).await;
}