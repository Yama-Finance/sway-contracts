library tests;

dep helpers;

use helpers::convert_amount;

#[test]
fn test_convert_amount() {
  assert(
    convert_amount(5, 0, 2) == 500
  );
  assert(
    convert_amount(100, 2, 0) == 1
  );
}