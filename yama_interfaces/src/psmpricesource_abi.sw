library psmpricesource_abi;

use fixed_point::ufp128::UFP128;
use yama_types::ufp128::*;

abi PSMPriceSource {
    fn price() -> UFP128;
}
