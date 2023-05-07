contract;

use yama_interfaces::psmpricesource_abi::PSMPriceSource;
use fixed_point::ufp128::UFP128;
use yama_types::ufp128::*;

impl PSMPriceSource for Contract {
    fn price() -> UFP128 {
        UFP128::from_u64(1)
    }
}