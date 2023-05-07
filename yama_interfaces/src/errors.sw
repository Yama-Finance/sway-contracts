library errors;

pub enum BridgeError {
  InvalidMetadata: (),
  InvalidSourceBridge: (),
  NotMailbox: (),
  InvalidCallbackContract: (),
}

pub enum CDPError {
  InvalidDebtAmount: (),
  Undercollateralized: (),
  NotUndercollateralized: (),
  LoanAmountIsZero: (),
  BorrowingDisabled: (),
  CollateralTypeBorrowingDisabled: (),
  NotVaultOwner: (),
  Liquidated: (),
  BorrowerNotAllowed: (),
  ExceedsDebtCeiling: (),
  RepayOverpayment: (),
  Reentrancy: (),
}

pub enum DutchAuctionLiquidatorError {
  AuctionDone: (),
  AuctionExpired: (),
  InvalidPayment: (),
  AuctionNotExpired: (),
  ExceedsMaxPrice: (),
}

pub enum ModularTokenError {
  Uninitialized: (),
  UnauthorizedUser: ()
}

pub enum PSMError {
  ExceedsDebtCeiling: (),
}

pub enum FlashMintModuleError {
  InvalidRepaySender: (),
  NoLoanToRepay: (),
  NotRepaid: (),
  RepayOverpayment: (),
  ExceedsMax: (),
}

pub enum YamaLibraryError {
  InvalidToken: (),
}

pub enum SimpleBSHError {
  NotBalanceSheet: (),
  RevenueShareExceedsDenominator: (),
}

pub enum LeverageProxyError {
  NotFlashMintModule: (),
  InitiatorNotThis: (),
  NotVaultOwner: (),
}

pub enum SwapperError {
  InsufficientInput: (),
}