///|
test "CBOR integer extrema are exact and outside values are rejected" {
  let unsigned = parse_cddl("root = 18446744073709551615").unwrap()
  assert_true(
    validate(unsigned, UnsignedValue(18446744073709551615UL))
    .unwrap()
    .is_valid(),
  )
  assert_false(
    validate(unsigned, UnsignedValue(18446744073709551614UL))
    .unwrap()
    .is_valid(),
  )
  let negative = parse_cddl("root = -18446744073709551616").unwrap()
  assert_true(
    validate(negative, NegativeValue(18446744073709551615UL))
    .unwrap()
    .is_valid(),
  )
  assert_true(parse_cddl("root = 18446744073709551616") is Err(_))
  assert_true(parse_cddl("root = -18446744073709551617") is Err(_))
  for source in ["root = 0xffffffffffffffff", "root = -0x10000000000000000"] {
    assert_true(parse_cddl(source) is Ok(_))
  }
}

///|
test "integer float and named ranges retain their standard domains" {
  let document = parse_cddl("root = lower .. upper lower = 0.0 upper = 2.0").unwrap()
  assert_true(validate(document, float_value(1.5)).unwrap().is_valid())
  assert_false(validate(document, integer_value(1L)).unwrap().is_valid())
  let empty = parse_cddl("root = 10..1").unwrap()
  assert_false(validate(empty, integer_value(5L)).unwrap().is_valid())
  let wide = parse_cddl("root = 9223372036854775808..18446744073709551615").unwrap()
  assert_true(
    validate(wide, UnsignedValue(18446744073709551615UL)).unwrap().is_valid(),
  )
  assert_false(validate(wide, integer_value(1L)).unwrap().is_valid())
}

///|
test "major types and tag contents validate independently" {
  let document = parse_cddl("root = #6.18446744073709551615(uint)").unwrap()
  assert_true(
    validate(document, WideTagValue(18446744073709551615UL, integer_value(1L)))
    .unwrap()
    .is_valid(),
  )
  assert_false(
    validate(document, WideTagValue(18446744073709551615UL, text_value("bad")))
    .unwrap()
    .is_valid(),
  )
  let any_tag = parse_cddl("root = #6(tstr)").unwrap()
  assert_true(
    validate(any_tag, tagged_value(123L, text_value("ok"))).unwrap().is_valid(),
  )
  let cases : Array[(String, CddlValue)] = [
    ("root = #", NullValue),
    ("root = #0", UnsignedValue(18446744073709551615UL)),
    ("root = #1", NegativeValue(18446744073709551615UL)),
    ("root = #7.23", SimpleValue(23)),
  ]
  for (source, value) in cases {
    assert_true(
      validate(parse_cddl(source).unwrap(), value).unwrap().is_valid(),
    )
  }
}

///|
test "float prelude checks representability rather than original wire width" {
  let half = parse_cddl("root = float16").unwrap()
  for value in [0.0, 1.5, 65504.0, 0.000000059604644775390625] {
    assert_true(validate(half, float_value(value)).unwrap().is_valid())
  }
  assert_false(validate(half, float_value(0.1)).unwrap().is_valid())
  let single = parse_cddl("root = float32").unwrap()
  assert_true(validate(single, float_value(1.5)).unwrap().is_valid())
  assert_false(validate(single, float_value(0.1)).unwrap().is_valid())
}

///|
test "all Appendix D prelude names resolve without textual injection" {
  let names = [
    "any", "uint", "nint", "int", "bstr", "bytes", "tstr", "text", "tdate", "time",
    "number", "biguint", "bignint", "bigint", "integer", "unsigned", "decfrac", "bigfloat",
    "eb64url", "eb64legacy", "eb16", "encoded-cbor", "uri", "b64url", "b64legacy",
    "regexp", "mime-message", "cbor-any", "float16", "float32", "float64", "float16-32",
    "float32-64", "float", "false", "true", "bool", "nil", "null", "undefined",
  ]
  for name in names {
    assert_true(parse_cddl("root = " + name) is Ok(_), msg=name)
  }
  assert_true(
    validate(
      parse_cddl("root = uri").unwrap(),
      tagged_value(32L, text_value("https://example.org")),
    )
    .unwrap()
    .is_valid(),
  )
  assert_true(
    validate(parse_cddl("root = undefined").unwrap(), SimpleValue(23))
    .unwrap()
    .is_valid(),
  )
}

///|
test "floating numeric literal bases and escaped byte string forms round trip" {
  let cases : Array[(String, CddlValue)] = [
    ("root = 0x1.8p+1", FloatValue(3.0)),
    ("root = 1e3", FloatValue(1000.0)),
    ("root = 0.1", FloatValue(0.1)),
    ("root = b64'AQID'", BytesValue(b"\x01\x02\x03")),
    ("root = '\\u0041'", BytesValue(b"A")),
    ("root = \"\\uD83D\\uDE00\"", TextValue("😀")),
  ]
  for (source, value) in cases {
    let document = parse_cddl(source).unwrap()
    assert_true(validate(document, value).unwrap().is_valid(), msg=source)
    let formatted = format_cddl(document).unwrap()
    assert_true(
      validate(parse_cddl(formatted).unwrap(), value).unwrap().is_valid(),
      msg=formatted,
    )
  }
  assert_true(parse_cddl("root = \"\\uD800\"") is Err(_))
  assert_true(parse_cddl("root = b64'%' ") is Err(_))
}
