use tokio::sync::Mutex;
use lazy_static::lazy_static;
use fuels::{prelude::*, tx::ContractId, types::{
  Identity,
  Bits256
}, signers::fuel_crypto::coins_bip32::enc::Test};
use crate::{
    abigen::*,
    utils::{
        set_storage_val, test_deploy
    },
    modulartoken::{
        get_cid, init_modulartoken
    },
    flashmintmodule::init_custom_flashmintmodule, balancesheet, testswapper::init_custom_testswapper, cdp::get_collateral_manager
};


lazy_static! {
    static ref MUTEX: Mutex<i32> = Mutex::new(0i32);
}

pub async fn init_lproxy() -> (
    WalletUnlocked,
    ModularToken,
    ModularToken,
    FlashMintModule,
    CDP,
    LeverageProxy
) {
    let (
        _,
        wallet,
        stable_i,
        collat_i,
        _,
        _,
        _,
        _,
        cdp,
        _
    ) = test_deploy().await;
    let flashmintmodule
        = init_custom_flashmintmodule(&wallet, &stable_i).await;
    let lproxy
        = init_custom_lproxy(
            &wallet,
            &stable_i,
            &ContractId::from(flashmintmodule.get_contract_id()),
            &ContractId::from(cdp.get_contract_id())
        ).await;

    let swapper: TestSwapper = init_custom_testswapper(
        &wallet,
        &stable_i,
        &collat_i
    ).await;

    set_collateral_type_config(
        &lproxy,
        stable_i.get_contract_id(),
        0,
        &ContractId::from(collat_i.get_contract_id()),
        &ContractId::from(swapper.get_contract_id())
    ).await;

    (
        wallet,
        stable_i,
        collat_i,
        flashmintmodule,
        cdp,
        lproxy
    )
}

pub async fn init_custom_lproxy(
    wallet: &WalletUnlocked,
    stable_i: &ModularToken,
    flash_mint_module: &ContractId,
    cdp_module: &ContractId,
) -> LeverageProxy {
    let storage_path = "../leverageproxy/out/debug/leverageproxy-storage_slots.json";

    let guard = MUTEX.lock().await;

    // Create a Mutex to synchronize access to the storage slots
    set_storage_val(
        &storage_path,
        "storage_0",
        &get_cid(stable_i).to_string()
    );
    set_storage_val(
        &storage_path,
        "storage_1",
        &flash_mint_module.to_string()
    );
    set_storage_val(
        &storage_path,
        "storage_2",
        &cdp_module.to_string()
    );
    let id = Contract::deploy(
        "../leverageproxy/out/debug/leverageproxy.bin",
        &wallet,
        TxParameters::default(),
        StorageConfiguration::with_storage_path(Some(
            storage_path.to_string()
        ))
    )
    .await
    .unwrap();

    drop(guard);

    let lproxy = LeverageProxy::new(id, wallet.clone());
    lproxy
}

pub async fn set_collateral_type_config(
    instance: &LeverageProxy,
    stable_i: &Bech32ContractId,
    collateral_type_id: u64,
    collateral: &ContractId,
    swapper: &ContractId,
) {
    instance
        .methods()
        .set_collateral_type_config(
            collateral_type_id,
            Bits256::from_hex_str(&*collateral.to_string()).unwrap(),
            Bits256::from_hex_str(&*swapper.to_string()).unwrap(),
        )
        .set_contract_ids(&[stable_i.clone()])
        .call()
        .await
        .unwrap();
}

pub async fn create_vault(
    instance: &LeverageProxy,
    collat_i: &Bech32ContractId,
    collateral_type_id: u64,
    collateral_amount: u64,
    cdp: &CDP,
) -> u64 {
    let call_params = CallParameters::new(
        Some(collateral_amount),
        Some(AssetId::new(*ContractId::from(collat_i.clone()))),
        None
    );
    
    instance
        .methods()
        .create_vault(collateral_type_id)
        .call_params(call_params)
        .set_contract_ids(&[
            collat_i.clone(),
            get_collateral_manager(cdp).await,
            cdp.get_contract_id().clone()
        ])
        .call()
        .await
        .unwrap()
        .value
}

pub async fn leverage_up(
    instance: &LeverageProxy,
    vault_id: u64,
    yama_borrowed: u64,
    min_collat_swapped: u64,
    cdp: &CDP,
    flash_mint_module: &Bech32ContractId
) {
    instance
        .methods()
        .leverage_up(vault_id, yama_borrowed, min_collat_swapped)
        .set_contract_ids(&[
            flash_mint_module.clone(),
            get_collateral_manager(cdp).await,
            cdp.get_contract_id().clone()
        ])
        .call()
        .await
        .unwrap();
}

pub async fn leverage_down(
    instance: &LeverageProxy,
    vault_id: u64,
    collat_sold: u64,
    min_yama_repaid: u64,
    cdp: &CDP,
    flash_mint_module: &Bech32ContractId
) {
    instance
        .methods()
        .leverage_down(vault_id, collat_sold, min_yama_repaid)
        .set_contract_ids(&[
            flash_mint_module.clone(),
            get_collateral_manager(cdp).await,
            cdp.get_contract_id().clone()
        ])
        .call()
        .await
        .unwrap();
}
pub async fn leverage_down_all(
    instance: &LeverageProxy,
    vault_id: u64,
    min_yama_repaid: u64,
    cdp: &CDP,
    flash_mint_module: &Bech32ContractId
) {
    instance
        .methods()
        .leverage_down_all(vault_id, min_yama_repaid)
        .set_contract_ids(&[
            flash_mint_module.clone(),
            get_collateral_manager(cdp).await,
            cdp.get_contract_id().clone()
        ])
        .call()
        .await
        .unwrap();
}