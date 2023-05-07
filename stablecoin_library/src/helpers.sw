library helpers;

dep constants;

use std::{
  auth::msg_sender,
  math::*,
  call_frames::msg_asset_id,
  contract_id::ContractId,
  revert::require,
  u256::U256,
  bytes::Bytes
};
use yama_interfaces::{
  modulartoken_abi::ModularToken,
  flashmintmodule_abi::FlashMintModule,
  balancesheetmodule_abi::BalanceSheetModule,
  errors::YamaLibraryError
};
use constants::{
  DECIMALS
};
use fixed_point::ufp128::UFP128;
use yama_types::ufp128::*;
use signed_integers::i256::I256;

pub fn sender_id() -> Identity {
  msg_sender().unwrap()
}

pub fn verify_sender_allowed(stablecoin_contract: b256) {
  let stablecoin = abi(ModularToken, stablecoin_contract);
  stablecoin.verify_allowed(sender_id());
}

pub fn verify_tokens_from(asset_id: b256) {
  require(msg_asset_id() == ContractId::from(asset_id),
    YamaLibraryError::InvalidToken)
}

pub fn mint(amount: u64, account: Identity, stablecoin_contract: b256) {
  let stablecoin = abi(ModularToken, stablecoin_contract);
  stablecoin.mint(amount, account);
}

pub fn burn(amount: u64, stablecoin_contract: b256) {
  let stablecoin = abi(ModularToken, stablecoin_contract);
  stablecoin.burn{asset_id: stablecoin_contract, coins: amount}();
}

pub fn add_surplus(amount: I256, balancesheet_module: b256) {
  let balancesheet = abi(BalanceSheetModule, balancesheet_module);
  balancesheet.add_surplus(amount);
}

pub fn add_deficit(amount: I256, balancesheet_module: b256) {
  let balancesheet = abi(BalanceSheetModule, balancesheet_module);
  balancesheet.add_deficit(amount);
}

pub fn total_surplus(balancesheet_module: b256) -> I256 {
  let balancesheet = abi(BalanceSheetModule, balancesheet_module);
  balancesheet.total_surplus()
}

pub fn flash_loan(amount: u64, calldata: Vec<u8>, flash_mint_module: b256) {
  let flash_mint = abi(FlashMintModule, flash_mint_module);
  flash_mint.flash_loan(amount, calldata);
}

pub fn convert_amount(amount: u64, from_decimals: u8, to_decimals: u8) -> u64 {
  if (from_decimals == to_decimals) {
    return amount;
  } else if (from_decimals < to_decimals) {
    return amount * (10 ** (to_decimals - from_decimals));
  } else {
    return amount / (10 ** (from_decimals - to_decimals));
  }
}

pub fn convert_amount_u256(amount: U256, from_decimals: u8, to_decimals: u8) -> U256 {
  let ten_u256 = U256::from((0, 0, 0, 10));
  if (from_decimals == to_decimals) {
    return amount;
  } else if (from_decimals < to_decimals) {
    let mut current_decimals = from_decimals;
    let mut current_amount = amount;
    while (current_decimals < to_decimals) {
      current_amount *= ten_u256;
      current_decimals += 1;
    }
    return current_amount;
  } else {
    let mut current_decimals = from_decimals;
    let mut current_amount = amount;
    while (current_decimals > to_decimals) {
      current_amount /= ten_u256;
      current_decimals -= 1;
    }
    return current_amount;
  }
}

pub fn tokens_to_fp(amount: u64) -> UFP128 {
  UFP128::from_u64(amount)
}

pub fn fp_to_tokens(amount: UFP128) -> u64 {
  amount.to_u64()
}

pub fn fp_to_i256_tokens(amount: UFP128) -> I256 {
  amount.to_i256()
}

pub fn u64_to_i256(amount: u64) -> I256 {
  I256::from(U256::from((0, 0, 0, amount)))
}

pub fn i256_to_u64(amount: I256) -> u64 {
  amount.underlying.d
}

pub fn safe_unwrap_bool(result: Option<bool>) -> bool {
  match result {
    Option::Some(value) => value,
    Option::None => false,
  }
}