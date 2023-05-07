use fuels::{prelude::*, tx::ContractId};
use crate::abigen::*;

pub async fn init_emptycollateralmanager(
  wallet: WalletUnlocked) -> EmptyCollateralManager
  {
  let id = Contract::deploy(
    "../emptycollateralmanager/out/debug/emptycollateralmanager.bin",
    &wallet,
    TxParameters::default(),
    StorageConfiguration::default(),
  )
  .await
  .unwrap();
  
  EmptyCollateralManager::new(id, wallet)
}