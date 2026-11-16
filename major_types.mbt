///|
fn half_representable(value : Double) -> Bool {
  let value = value.abs()
  if value != value || value == 1.0 / 0.0 || value == 0.0 {
    return true
  }
  if value > 65504.0 {
    return false
  }
  let scaled = if value < 0.00006103515625 {
    value * 16777216.0
  } else {
    value * @math.pow(2.0, 10.0 - @math.log2(value).floor())
  }
  scaled == scaled.floor()
}

///|
fn major_matches(major : Int32, argument : UInt64?, value : CddlValue) -> Bool {
  match (major, value) {
    (0, _) =>
      match unsigned_component(value) {
        Some(n) => argument is None || argument == Some(n)
        None => false
      }
    (1, _) =>
      match negative_component(value) {
        Some(n) => argument is None || argument == Some(n)
        None => false
      }
    (2, BytesValue(bytes)) =>
      argument is None || argument == Some(bytes.length().to_uint64())
    (3, TextValue(text)) =>
      argument is None ||
      argument == Some(@utf8.encode(text[:]).length().to_uint64())
    (4, ArrayValue(items)) =>
      argument is None || argument == Some(items.length().to_uint64())
    (5, MapValue(items)) =>
      argument is None || argument == Some(items.length().to_uint64())
    (6, TaggedValue(tag, _)) =>
      argument is None ||
      (tag >= 0L && argument == Some(tag.reinterpret_as_uint64()))
    (6, WideTagValue(tag, _)) => argument is None || argument == Some(tag)
    (7, BoolValue(false)) => argument is None || argument == Some(20UL)
    (7, BoolValue(true)) => argument is None || argument == Some(21UL)
    (7, NullValue) => argument is None || argument == Some(22UL)
    (7, SimpleValue(n)) => argument is None || argument == Some(n.to_uint64())
    (7, FloatValue(n) | EncodedFloat(_, n)) =>
      match argument {
        None | Some(27UL) => true
        Some(26UL) => n != n || Float::from_double(n).to_double() == n
        Some(25UL) => half_representable(n)
        _ => false
      }
    _ => false
  }
}

///|
fn major_witness(
  major : Int32,
  argument : UInt64?,
) -> Result[CddlValue, CddlError] {
  let n = argument.unwrap_or(0UL)
  match major {
    0 => Ok(exact_uint(n))
    1 => Ok(exact_negative(n))
    6 =>
      Ok(
        if n <= 9223372036854775807UL {
          TaggedValue(n.reinterpret_as_int64(), NullValue)
        } else {
          WideTagValue(n, NullValue)
        },
      )
    7 =>
      match argument {
        Some(20UL) => Ok(BoolValue(false))
        Some(21UL) => Ok(BoolValue(true))
        Some(22UL) => Ok(NullValue)
        Some(25UL) | Some(26UL) | Some(27UL) => Ok(FloatValue(0.0))
        None => Ok(NullValue)
        Some(n) if n <= 255UL => Ok(SimpleValue(n.to_int()))
        _ =>
          Err(
            cddl_error(
              ValidationFailure,
              "no simple value for additional information",
            ),
          )
      }
    _ =>
      Err(
        cddl_error(
          UnsupportedFeature,
          "generator does not allocate arbitrary major-type sizes",
        ),
      )
  }
}
