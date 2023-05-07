contract;

use std::{
  identity::Identity,
  call_frames::{
    msg_asset_id,
    contract_id
  },
  context::msg_amount,
  token::{
    mint_to,
    burn
  },
  logging::log
};

use yama_interfaces::{
  modulartoken_abi::ModularToken,
  errors::ModularTokenError,
  events::SetAllowlist
};
use stablecoin_library::{
  helpers::{
    sender_id,
    verify_tokens_from,
    safe_unwrap_bool
  },
  constants::{
    INITIAL_OWNER,
    STR_64,
    STR_32,
    DECIMALS
  }
};

storage {
  allowlist: StorageMap<Identity, bool> = StorageMap{},
  initialized: bool = false,
  initial_owner: Identity = Identity::Address(Address{
    value: INITIAL_OWNER}),
  total_supply: u64 = 0,
  name: str[64] = STR_64,
  symbol: str[32] = STR_32
}

impl ModularToken for Contract {
  #[storage(read, write)]
  fn mint(amount: u64, account: Identity) {
    verify_account_allowed(sender_id());
    if amount > 0 {
      mint_to(amount, account);
    }
    storage.total_supply += amount;
  }

  #[payable]
  #[storage(read, write)]
  fn burn() {
    verify_account_allowed(sender_id());
    verify_tokens_from(contract_id().value);
    burn(msg_amount());
    storage.total_supply -= msg_amount();
  }

  #[storage(read, write)]
  fn set_allowlist(account: Identity, is_allowed: bool) {
    verify_account_allowed(sender_id());
    set_allowlist(account, is_allowed);
  }

  #[storage(read)]
  fn get_allowlist(account: Identity) -> bool {
    safe_unwrap_bool(storage.allowlist.get(account))
  }
  
  #[storage(read, write)]
  fn init_allowlist() {
    require(!storage.initialized, ModularTokenError::Uninitialized);
    set_allowlist(storage.initial_owner, true);
    storage.initialized = true;
  }

  #[storage(read)]
  fn verify_allowed(account: Identity) {
    verify_account_allowed(account);
  }

  #[storage(read)]
  fn total_supply() -> u64 {
    storage.total_supply
  }

  #[storage(read)]
  fn name() -> str[64] {
    storage.name
  }

  #[storage(read)]
  fn symbol() -> str[32] {
    storage.symbol
  }

  #[storage(read)]
  fn decimals() -> u8 {
    DECIMALS
  }
}

#[storage(read)]
fn verify_account_allowed(account: Identity) {
  require(safe_unwrap_bool(storage.allowlist.get(account)),
    ModularTokenError::UnauthorizedUser);
}

#[storage(write)]
fn set_allowlist(account: Identity, is_allowed: bool) {
  storage.allowlist.insert(account, is_allowed);
  log(SetAllowlist {
    account: account,
    is_allowed: is_allowed
  });
}