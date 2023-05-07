use fuels::prelude::*;
use sdk_utils::{
    psmlockup::*,
    modulartoken::{
        mint,
        get_aid
    },
    abigen::*
};

#[tokio::test]
async fn test_lockup() {
    let (
        psm_lockup,
        wallet,
        stable_i,
        ext_i,
        psm
    ) = init_psmlockup().await;
    let stable_aid = get_aid(&stable_i);
    let ext_aid = get_aid(&ext_i);
    let lockup_aid = AssetId::new(*ContractId::from(psm_lockup.get_contract_id()));
    mint(&ext_i, &wallet, 100).await;
    lockup(
        &psm_lockup,
        &psm.get_contract_id(),
        &stable_i.get_contract_id(),
        &ext_aid,
        100
    ).await;

    assert_eq!(
        wallet.get_asset_balance(&stable_aid).await.unwrap(),
        0
    );

    assert_eq!(
        wallet.get_asset_balance(&lockup_aid).await.unwrap(),
        100
    );
    assert_eq!(
        value(&psm_lockup, &stable_i.get_contract_id()).await,
        UFP128 { value: U128 { upper: 1, lower: 0 } }
    );
    mint(&stable_i, &wallet, 100).await;
    wallet.force_transfer_to_contract(
        psm_lockup.get_contract_id(),
        100,
        stable_aid.clone(),
        TxParameters::default()
    ).await.unwrap();
    assert_eq!(
        value(&psm_lockup, &stable_i.get_contract_id()).await,
        UFP128 { value: U128 { upper: 2, lower: 0 } }
    );
    redeem(
        &psm_lockup,
        &psm.get_contract_id(),
        &stable_i.get_contract_id(),
        100
    ).await;

    assert_eq!(
        wallet.get_asset_balance(&stable_aid).await.unwrap(),
        200
    );
}