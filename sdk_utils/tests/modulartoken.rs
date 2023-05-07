use fuels::{prelude::*, types::Identity};
use sdk_utils::{
    utils::get_id,
    modulartoken::{
        mint,
        init_modulartoken,
        get_allowlist,
        set_allowlist,
        get_aid
    }
};


#[tokio::test]
async fn authorized_mint() {
    let (instance, wallet)
        = init_modulartoken().await;
    

    println!("{}", get_aid(&instance));
    let wallet_address = Address::new(*wallet.address().hash());
    let wallet_id = Identity::Address(wallet_address);
    println!("{}", get_allowlist(&instance, wallet_id).await);


    assert_eq!(
        wallet.get_asset_balance(&get_aid(&instance)).await.unwrap(),
        0
    );

    println!("Test2");
    mint(&instance, &wallet, 10).await;
    
    println!("Test3");
    assert_eq!(
        wallet.get_asset_balance(&get_aid(&instance)).await.unwrap(),
        10
    );
}

#[tokio::test]
async fn authorization() {
    let (instance, wallet)
        = init_modulartoken().await;
    let wallet_address = Address::new(*wallet.address().hash());
    let wallet_id = Identity::Address(wallet_address);
    
    assert_eq!(get_allowlist(&instance,
        Identity::ContractId(ContractId::zeroed())).await, false);


    assert_eq!(get_allowlist(&instance, wallet_id).await, true);
}

#[tokio::test]
#[should_panic]
async fn unauthorized_mint() {
    let (instance, wallet)
        = init_modulartoken().await;
    
    mint(&instance, &wallet, 10).await;
    assert_eq!(
        wallet.get_asset_balance(&get_aid(&instance)).await.unwrap(),
        0
    );
}


#[tokio::test]
async fn burn_test() {
    let (instance, wallet)
        = init_modulartoken().await;
    
    mint(&instance, &wallet, 10).await;

    assert_eq!(
        wallet.get_asset_balance(&get_aid(&instance)).await.unwrap(),
        10
    );

    let _result = instance
        .methods()
        .burn()
        .call_params(CallParameters::new(Some(10), Some(get_aid(&instance)), None))
        .call()
        .await
        .unwrap();

    assert_eq!(
        wallet.get_asset_balance(&get_aid(&instance)).await.unwrap(),
        0
    );
}

#[tokio::test]
#[should_panic]
async fn unauthorized_burn() {
    let (instance, wallet)
        = init_modulartoken().await;
    // Mint tokens
    
    mint(&instance, &wallet, 10).await;

    assert_eq!(
        wallet.get_asset_balance(&get_aid(&instance)).await.unwrap(),
        10
    );

    set_allowlist(&instance, get_id(&wallet), false).await;

    // Burn tokens
    let _result = instance
        .methods()
        .burn()
        .call_params(CallParameters::new(Some(10), Some(get_aid(&instance)), None))
        .call()
        .await
        .unwrap();

}


// Test set_allowlist
#[tokio::test]
async fn set_allowlist_test() {
    let (instance, wallet)
        = init_modulartoken().await;

    let wallet_id = get_id(&wallet);

    assert_eq!(get_allowlist(&instance, wallet_id.clone()).await, true);

    set_allowlist(&instance, wallet_id.clone(), false).await;
    assert_eq!(get_allowlist(&instance, wallet_id).await, false);
}
