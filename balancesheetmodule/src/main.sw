contract;

use yama_interfaces::{
  balancesheetmodule_abi::BalanceSheetModule,
  modulartoken_abi::ModularToken,
  balancesheethandler_abi::BalanceSheetHandler,
  events::{
    AddSurplus,
    AddDeficit,
    SetSurplus,
    SetHandler
  }
};
use stablecoin_library::{
  helpers::verify_sender_allowed,
  helpers::sender_id,
  constants::ZERO_B256
};
use signed_integers::i256::I256;
use std::{
  u256::U256,
  logging::log
};

storage {
  stablecoin_contract: b256 = ZERO_B256,
  handler: b256 = ZERO_B256,
  surplus: I256 = I256::new()
}

impl BalanceSheetModule for Contract {
    #[storage(read)]
    fn total_surplus() -> I256 {
      storage.surplus
    }
    #[storage(read, write)]
    fn add_surplus(amount: I256) {
      verify_sender_allowed(storage.stablecoin_contract);
      storage.surplus += amount;
      log(AddSurplus {
        account: sender_id(),
        amount: amount
      });
      if storage.handler != ZERO_B256 {
        let handler_contract = abi(BalanceSheetHandler, storage.handler);
        handler_contract.on_add_surplus(amount);
      }
    }
    #[storage(read, write)]
    fn add_deficit(amount: I256) {
      verify_sender_allowed(storage.stablecoin_contract);
      storage.surplus -= amount;
      log(AddDeficit {
        account: sender_id(),
        amount: amount
      });
      if storage.handler != ZERO_B256 {
        let handler_contract = abi(BalanceSheetHandler, storage.handler);
        handler_contract.on_add_deficit(amount);
      }
    }
    #[storage(read, write)]
    fn set_surplus(amount: I256) {
      verify_sender_allowed(storage.stablecoin_contract);
      storage.surplus = amount;
      log(SetSurplus {
        account: sender_id(),
        amount: amount
      });
    }

    #[storage(read)]
    fn get_handler() -> b256 {
      storage.handler
    }

    #[storage(read)]
    fn get_stablecoin_contract() -> b256 {
      storage.stablecoin_contract
    }

    #[storage(read, write)]
    fn set_handler(handler: b256) {
      verify_sender_allowed(storage.stablecoin_contract);
      storage.handler = handler;
      log(SetHandler {
        account: sender_id(),
        handler: handler
      });
    }
}
