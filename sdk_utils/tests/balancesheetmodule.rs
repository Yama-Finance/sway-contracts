use sdk_utils::{
    balancesheet::{
        init_balancesheet,
        add_surplus,
        add_deficit,
        total_surplus
    },
    modulartoken::{
        get_aid
    },
    abigen::*,
    utils::{u64_to_i256, get_id_key}
};



#[tokio::test]
async fn test_add_surplus() {
    let (
        wallet,
        stable_i,
        balancesheet,
        simplebsh
    ) = init_balancesheet().await;

    add_surplus(&balancesheet, stable_i.get_contract_id(),
        simplebsh.get_contract_id(),
        stable_i.get_contract_id(),
        u64_to_i256(100)).await;
    assert_eq!(
        total_surplus(&balancesheet, stable_i.get_contract_id()).await,
        u64_to_i256(10)
    );
    assert_eq!(
        *stable_i.get_balances().await.unwrap().get(&get_id_key(&get_aid(&stable_i))).unwrap(),
        90
    );

    add_deficit(&balancesheet, stable_i.get_contract_id(),
        simplebsh.get_contract_id(),
        stable_i.get_contract_id(),
        u64_to_i256(10)).await;
    assert_eq!(
        total_surplus(&balancesheet, stable_i.get_contract_id()).await,
        u64_to_i256(0)
    );
    assert_eq!(
        *stable_i.get_balances().await.unwrap().get(&get_id_key(&get_aid(&stable_i))).unwrap(),
        90
    );
}