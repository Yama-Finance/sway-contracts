use sdk_utils::{
    modulartoken::mint,
    leverageproxy::*
};

#[tokio::test]
async fn test_lproxy() {
    let (
        wallet,
        stable_i,
        collat_i,
        flashmintmodule,
        cdp,
        lproxy
    ) = init_lproxy().await;
    
    let collat_amount: u64 = 150;
    mint(&collat_i, &wallet, collat_amount).await;

    create_vault(
        &lproxy,
        collat_i.get_contract_id(),
        0,
        collat_amount,
        &cdp
    ).await;

    leverage_up(
        &lproxy,
        0,
        collat_amount + 25,
        collat_amount + 25,
        &cdp,
        flashmintmodule.get_contract_id()
    ).await;

    leverage_down(
        &lproxy,
        0,
        collat_amount,
        collat_amount,
        &cdp,
        flashmintmodule.get_contract_id()
    ).await;

    leverage_down_all(
        &lproxy,
        0,
        0,
        &cdp,
        flashmintmodule.get_contract_id()
    ).await;
}