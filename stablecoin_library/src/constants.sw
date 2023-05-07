library constants;

use fixed_point::ufp128::UFP128;
use yama_types::ufp128::*;

pub const ZERO_B256
  = 0x0000000000000000000000000000000000000000000000000000000000000000;

pub const ONE_B256
  = 0x0000000000000000000000000000000000000000000000000000000000000001;

pub const STR_64
  = "                                                                ";
pub const STR_32
  = "                                ";

// ModularToken

pub const DECIMALS: u8 = 4;

pub const INITIAL_OWNER: b256 = ONE_B256;

// PSM

pub const PSM_CEILING: u64 = 1000000000000;

pub const PSM_TOKEN_DECIMALS: u8 = 4;

// DutchAuctionLiquidator

pub const DAL_DEFAULT_INITIAL_PRICE_RATIO: UFP128 = UFP128::zero();
pub const DAL_DEFAULT_TIME_INTERVAL: u64 = 0;

pub const DAL_CHANGE_RATE: UFP128 = UFP128::zero();

pub const DAL_RESET_THRESHOLD: u64 = 0;

pub const DAL_ENABLED: bool = true;  // Ignored

// FlashMintModule

pub const FMM_MAX: u64 = 1000000000000;

// SimpleBSH

pub const SBSH_REVENUE_SHARE: u64 = 9000;
pub const SBSH_DENOMINATOR: u64 = 10000;
pub const SECONDS_IN_YEAR: u64 = 31536000;