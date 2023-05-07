library events;

use signed_integers::i256::I256;
use fixed_point::ufp128::UFP128;
use yama_types::ufp128::*;

// Modular token

pub struct SetAllowlist {
  account: Identity,
  is_allowed: bool
}

// Balance sheet

pub struct AddSurplus {
  account: Identity,
  amount: I256
}

pub struct AddDeficit {
  account: Identity,
  amount: I256
}

pub struct SetSurplus {
  account: Identity,
  amount: I256
}

pub struct SetHandler {
  account: Identity,
  handler: b256
}

// Bridge

pub struct RemoteTransferSent {
  from_id: Identity,
  dst_chain: u32,
  to_id: b256,
  metadata: u32,
  amount: u64,
}

pub struct RemoteTransferReceived {
  from_id: b256,
  src_chain: u32,
  to_id: Identity,
  amount: u64,
}

pub struct SetBridge {
  account: Identity,
  chain: u32,
  bridge: b256
}

// CDP

pub struct SetDebt {
  account: Identity,
  vault_id: u64,
  debt: UFP128,
  initial_debt: UFP128
}

pub struct Borrow {
  account: Identity,
  vault_id: u64,
  amount: u64
}

pub struct Repay {
  account: Identity,
  vault_id: u64,
  amount: u64
}

pub struct AddCollateral {
  account: Identity,
  vault_id: u64,
  amount: u64
}

pub struct RemoveCollateral {
  account: Identity,
  vault_id: u64,
  amount: u64
}

pub struct CreateVault {
  owner: Identity,
  alt_owner: Option<Identity>,
  vault_id: u64,
  collateral_type_id: u64,
  collateral_amount: u64
}

pub struct Liquidate {
  initiator: Identity,
  liquidated: Identity,
  vault_id: u64
}

pub struct AddCollateralType {
  collateral_type_id: u64,
  token: b256,
  price_source: b256,
  debt_floor: UFP128,
  debt_ceiling: UFP128,
  collateral_ratio: UFP128,
  interest_rate: UFP128,
  borrowing_enabled: bool,
  allowlist_enabled: bool
}

pub struct SetCollateralType {
  collateral_type_id: u64,
  token: b256,
  price_source: b256,
  debt_floor: UFP128,
  debt_ceiling: UFP128,
  collateral_ratio: UFP128,
  interest_rate: UFP128,
  borrowing_enabled: bool,
  allowlist_enabled: bool
}

pub struct UpdateInterest {
  collateral_type_id: u64,
  interest_rate: UFP128,
  last_update_time: u64,
  cumulative_interest: UFP128
}

pub struct ClearVault {
  account: Identity,
  vault_id: u64
}

// Dutch Auction liquidator

pub struct InitializeAuction {
  vault_id: u64,
  auction_id: u64,
  start_price: UFP128,
  start_time: u64
}

pub struct ResetAuction {
  initiator: Identity,
  vault_id: u64,
  auction_id: u64
}

pub struct ClaimAuction {
  claimer: Identity,
  vault_id: u64,
  auction_id: u64,
  price: u64
}

pub struct SetDefaultCTypeParams {
  initial_price_ratio: UFP128,
  time_interval: u64,
  change_rate: UFP128,
  reset_threshold: u64
}

pub struct SetCTypeParams {
  collateral_type_id: u64,
  initial_price_ratio: UFP128,
  time_interval: u64,
  change_rate: UFP128,
  reset_threshold: u64,
  enabled: bool
}

// PSM

pub struct SetDebtCeiling {
  account: Identity,
  debt_ceiling: u64
}

pub struct Deposit {
  account: Identity,
  ext_stable_amount: u64
}

pub struct Withdraw {
  account: Identity,
  yss_amount: u64
}

// PSM Lockup

pub struct Lockup {
  account: Identity,
  ext_stable_amount: u64,
  yama_amount: u64,
  lockup_amount: u64
}

pub struct Redeem {
  account: Identity,
  yama_amount: u64,
  lockup_amount: u64
}