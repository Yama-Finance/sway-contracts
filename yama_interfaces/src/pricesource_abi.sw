library pricesource_abi;

use fixed_point::ufp128::UFP128;
use yama_types::ufp128::*;

abi PriceSource {
    fn price() -> UFP128;
}
