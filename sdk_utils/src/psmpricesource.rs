use fuels::{prelude::*, tx::ContractId};
use crate::abigen::*;

pub async fn init_psmpricesource(
  wallet: &WalletUnlocked) -> PSMPriceSource
{
  let id = Contract::deploy(
    "../psmpricesource/out/debug/psmpricesource.bin",
    &wallet,
    TxParameters::default(),
    StorageConfiguration::default(),
  )
  .await
  .unwrap();
  
  PSMPriceSource::new(id, wallet.clone())
}