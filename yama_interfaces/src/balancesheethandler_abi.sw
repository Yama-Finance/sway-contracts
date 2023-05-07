library balancesheethandler_abi;

use signed_integers::i256::I256;

abi BalanceSheetHandler {
    #[storage(read, write)]
    fn on_add_surplus(amount: I256);

    #[storage(read, write)]
    fn on_add_deficit(amount: I256);
}