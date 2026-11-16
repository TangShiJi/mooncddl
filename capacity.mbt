///|
// A .size range on uint denotes the union of all permitted byte capacities.
// Its largest nonnegative integer therefore determines the resulting bound.
fn capacity_upper_bound(
  schema : Schema,
  expression : TypeExpr,
  depth : Int32,
) -> UInt64? {
  if depth > 128 {
    return None
  }
  match resolve_head(schema, expression, depth + 1) {
    Some(Literal(value)) => unsigned_component(value)
    Some(IntegerRange(lower, upper, inclusive)) => {
      let upper = if inclusive {
        upper
      } else if upper > -9223372036854775808L {
        upper - 1L
      } else {
        return None
      }
      if upper >= 0L && upper >= lower {
        Some(upper.reinterpret_as_uint64())
      } else {
        None
      }
    }
    Some(ValueRange(lower, upper, inclusive)) =>
      match unsigned_component(upper) {
        Some(n) if inclusive && compare_number(lower, upper) != Some(1) =>
          Some(n)
        Some(n) if !inclusive &&
          n > 0UL &&
          compare_number(lower, exact_uint(n - 1UL)) != Some(1) => Some(n - 1UL)
        _ => None
      }
    Some(DynamicRange(lower, upper, inclusive)) =>
      match
        (
          singleton_value(schema, lower, depth + 1),
          singleton_value(schema, upper, depth + 1),
        ) {
        (Some(a), Some(b)) =>
          capacity_upper_bound(schema, ValueRange(a, b, inclusive), depth + 1)
        _ => None
      }
    Some(Choice(items)) => {
      let mut upper : UInt64? = None
      for item in items {
        if capacity_upper_bound(schema, item, depth + 1) is Some(n) {
          if upper is None || n > upper.unwrap() {
            upper = Some(n)
          }
        }
      }
      upper
    }
    _ => None
  }
}
