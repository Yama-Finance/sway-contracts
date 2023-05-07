library modulartoken_abi;

abi ModularToken {
  #[storage(read, write)]
  fn mint(amount: u64, account: Identity);
  #[payable]
  #[storage(read, write)]
  fn burn();

  #[storage(read, write)]
  fn set_allowlist(account: Identity, is_allowed: bool);
  #[storage(read)]
  fn get_allowlist(account: Identity) -> bool;
  #[storage(read, write)]
  fn init_allowlist();
  #[storage(read)]
  fn verify_allowed(account: Identity);
  #[storage(read)]
  fn total_supply() -> u64;
  #[storage(read)]
  fn name() -> str[64];
  #[storage(read)]
  fn symbol() -> str[32];
  #[storage(read)]
  fn decimals() -> u8;
}