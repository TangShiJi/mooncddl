///|
fn unsigned_component(value : CddlValue) -> UInt64? {
  match value {
    IntegerValue(n) if n >= 0L => Some(n.reinterpret_as_uint64())
    UnsignedValue(n) => Some(n)
    _ => None
  }
}

///|
fn negative_component(value : CddlValue) -> UInt64? {
  match value {
    IntegerValue(n) if n < 0L => Some((-(n + 1L)).reinterpret_as_uint64())
    NegativeValue(n) => Some(n)
    _ => None
  }
}

///|
fn numeric_double(value : CddlValue) -> Double? {
  match value {
    IntegerValue(n) => Some(n.to_double())
    UnsignedValue(n) => Some(n.to_double())
    NegativeValue(n) => Some(-1.0 - n.to_double())
    FloatValue(n) | EncodedFloat(_, n) => Some(n)
    _ => None
  }
}

///|
fn compare_number(left : CddlValue, right : CddlValue) -> Int32? {
  let left_float = left is FloatValue(_) || left is EncodedFloat(_, _)
  let right_float = right is FloatValue(_) || right is EncodedFloat(_, _)
  if !left_float && right_float && numeric_double(left) is Some(_) {
    return compare_integer_float(left, numeric_double(right).unwrap())
  }
  if left_float && !right_float && numeric_double(right) is Some(_) {
    return compare_integer_float(right, numeric_double(left).unwrap()).map(order => {
      -order
    })
  }
  match (unsigned_component(left), unsigned_component(right)) {
    (Some(a), Some(b)) =>
      return Some(if a < b { -1 } else if a > b { 1 } else { 0 })
    _ => ()
  }
  match (negative_component(left), negative_component(right)) {
    (Some(a), Some(b)) =>
      return Some(if a > b { -1 } else if a < b { 1 } else { 0 })
    _ => ()
  }
  if unsigned_component(left) is Some(_) && negative_component(right) is Some(_) {
    return Some(1)
  }
  if negative_component(left) is Some(_) && unsigned_component(right) is Some(_) {
    return Some(-1)
  }
  match (numeric_double(left), numeric_double(right)) {
    (Some(a), Some(b)) if a == a && b == b =>
      Some(if a < b { -1 } else if a > b { 1 } else { 0 })
    _ => None
  }
}

///|
fn compare_integer_float(integer : CddlValue, float : Double) -> Int32? {
  if float != float {
    return None
  }
  if float >= 18446744073709551616.0 {
    return Some(-1)
  }
  if float < -18446744073709551616.0 {
    return Some(1)
  }
  let floor = float.floor()
  let integral = if floor >= 0.0 {
    if floor < 9223372036854775808.0 {
      IntegerValue(floor.to_int64())
    } else {
      exact_uint(
        (floor - 9223372036854775808.0).to_int64().reinterpret_as_uint64() +
        9223372036854775808UL,
      )
    }
  } else if floor >= -9223372036854775808.0 {
    IntegerValue(floor.to_int64())
  } else if floor == -18446744073709551616.0 {
    NegativeValue(18446744073709551615UL)
  } else {
    exact_negative(
      (-floor - 9223372036854775808.0).to_int64().reinterpret_as_uint64() +
      9223372036854775807UL,
    )
  }
  match compare_number(integer, integral) {
    Some(0) if floor != float => Some(-1)
    other => other
  }
}

///|
fn exact_uint(value : UInt64) -> CddlValue {
  if value <= 9223372036854775807UL {
    IntegerValue(value.reinterpret_as_int64())
  } else {
    UnsignedValue(value)
  }
}

///|
fn exact_negative(value : UInt64) -> CddlValue {
  if value <= 9223372036854775807UL {
    IntegerValue(-1L - value.reinterpret_as_int64())
  } else {
    NegativeValue(value)
  }
}

///|
fn parse_wide_integer(chars : Array[Char]) -> CddlValue? {
  let mut index = 0
  let negative = chars[0] == '-'
  if negative {
    index += 1
  }
  let mut base = 10UL
  if index + 1 < chars.length() && chars[index] == '0' {
    if chars[index + 1] == 'x' || chars[index + 1] == 'X' {
      base = 16UL
      index += 2
    } else if chars[index + 1] == 'b' || chars[index + 1] == 'B' {
      base = 2UL
      index += 2
    }
  }
  let mut value = 0UL
  while index < chars.length() {
    let digit = digit_value(chars[index]).to_uint64()
    if value > (18446744073709551615UL - digit) / base {
      // The sole additional magnitude admitted by CBOR is -2**64.
      if negative &&
        index + 1 == chars.length() &&
        value ==
        18446744073709551615UL / base +
        (if 18446744073709551615UL % base + 1UL == base { 1UL } else { 0UL }) &&
        digit == (18446744073709551615UL % base + 1UL) % base {
        return Some(NegativeValue(18446744073709551615UL))
      }
      return None
    }
    value = value * base + digit
    index += 1
  }
  Some(
    if negative && value > 0UL {
      exact_negative(value - 1UL)
    } else {
      exact_uint(value)
    },
  )
}

///|
#warnings("-deprecated")
fn parse_float_literal(chars : Array[Char]) -> Double? {
  let mut index = 0
  let negative = chars[0] == '-'
  if negative {
    index += 1
  }
  let hex = index + 1 < chars.length() &&
    chars[index] == '0' &&
    (chars[index + 1] == 'x' || chars[index + 1] == 'X')
  if !hex {
    let text = chars_to_string(chars)
    return try @json.parse(text[:]) catch {
      _ => None
    } noraise {
      Number(n, ..) => Some(n)
      _ => None
    }
  }
  if hex {
    index += 2
  }
  let base = if hex { 16.0 } else { 10.0 }
  let mut value = 0.0
  let mut fraction = false
  let mut divisor = 1.0
  while index < chars.length() {
    let c = chars[index]
    if c == '.' {
      fraction = true
      index += 1
      continue
    }
    if (hex && (c == 'p' || c == 'P')) || (!hex && (c == 'e' || c == 'E')) {
      break
    }
    if fraction {
      divisor *= base
      value += digit_value(c).to_double() / divisor
    } else {
      value = value * base + digit_value(c).to_double()
    }
    index += 1
  }
  if index < chars.length() {
    index += 1
    let mut exp_negative = false
    if chars[index] == '-' {
      exp_negative = true
      index += 1
    } else if chars[index] == '+' {
      index += 1
    }
    let mut exponent = 0
    while index < chars.length() {
      if exponent < 10000 {
        exponent = exponent * 10 + digit_value(chars[index])
      }
      index += 1
    }
    let scale = @math.pow(
      if hex {
        2.0
      } else {
        10.0
      },
      (if exp_negative { -exponent } else { exponent }).to_double(),
    )
    value *= scale
  }
  Some(if negative { -value } else { value })
}
