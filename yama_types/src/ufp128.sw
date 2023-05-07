library ufp128;

use fixed_point::ufp128::*;
use std::{
    u128::U128,
    u256::U256,
};
use signed_integers::i256::I256;

impl UFP128 {
    pub fn from_u64(value: u64) -> Self {
        Self {
            value: U128::from((value, 0))
        }
    }

    pub fn to_u64(self) -> u64 {
        self.value.upper
    }

    pub fn to_i256(self) -> I256 {
       I256::from(U256::from((0, 0, 0, self.value.upper)))
    }
}

impl UFP128 {
    // https://github.com/paulrberg/prb-math/blob/88d0815baef78c0699fec1ff10b34a35903e110f/contracts/PRBMathUD60x18.sol#L455
    // Raises a UFP128 to an integer.
    pub fn powu(self, exponent_original: u64) -> Self {
        let mut exponent: u64 = exponent_original;

        let mut base: Self = self;

        let mut result = if (exponent & 1 > 0)
            { base } else { Self::from_u64(1) };

        exponent >>= 1;
        while (exponent > 0) {
            base *= base;

            if (exponent & 1 > 0) {
            result *= base;
            }
            exponent >>= 1;
        }

        result
    }
}

impl UFP128 {
    pub fn ge(self, other: Self) -> bool {
        self > other || self == other
    }
    pub fn le(self, other: Self) -> bool {
        self < other || self == other
    }
}

#[test]
fn test_powu() {
    let a = UFP128::from_u64(2);
    let b = a.powu(2);
    assert(b.to_u64() == 4);
}