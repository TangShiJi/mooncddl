///|
fn data_equal(
  left : CddlValue,
  right : CddlValue,
  cross_numeric : Bool,
) -> Bool {
  let left_float = left is FloatValue(_) || left is EncodedFloat(_, _)
  let right_float = right is FloatValue(_) || right is EncodedFloat(_, _)
  if (cross_numeric || left_float == right_float) &&
    compare_number(left, right) == Some(0) {
    return true
  }
  match (left, right) {
    (ArrayValue(a), ArrayValue(b)) => {
      if a.length() != b.length() {
        return false
      }
      for index, item in a {
        if !data_equal(item, b[index], false) {
          return false
        }
      }
      true
    }
    (MapValue(a), MapValue(b)) =>
      a.length() == b.length() &&
      a.all(entry => {
        b.any(other => {
          data_equal(entry.0, other.0, false) &&
          data_equal(entry.1, other.1, false)
        })
      })
    (TaggedValue(a, av), TaggedValue(b, bv)) =>
      a == b && data_equal(av, bv, false)
    (WideTagValue(a, av), WideTagValue(b, bv)) =>
      a == b && data_equal(av, bv, false)
    _ => left == right
  }
}
