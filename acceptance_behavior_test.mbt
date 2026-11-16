///|
test "JSON Appendix E unifies integral decimal values and representation types" {
  for
    (source, text) in [
      ("root = uint", "10.0"),
      ("root = float", "10"),
      ("root = #0", "9007199254740992.0"),
      ("root = #1", "-9223372036854775808.0"),
      ("root = 18446744073709551615", "18446744073709551615"),
    ] {
    assert_true(
      validate_json(parse_cddl(source).unwrap(), text).unwrap().is_valid(),
      msg=source,
    )
  }
  assert_true(parse_json_value("18446744073709551616") is Err(_))
  assert_false(
    validate_json(parse_cddl("root = uint").unwrap(), "1.5").unwrap().is_valid(),
  )
  assert_false(
    validate(parse_cddl("root = uint").unwrap(), FloatValue(10.0))
    .unwrap()
    .is_valid(),
  )
}

///|
test "size ranges are capacities and string sizes count UTF8 bytes" {
  for
    source in [
      "root = uint .size (9..10)", "root = uint .size 9", "root = uint .size (0 / 10)",
    ] {
    assert_true(
      validate(
        parse_cddl(source).unwrap(),
        UnsignedValue(18446744073709551615UL),
      )
      .unwrap()
      .is_valid(),
    )
  }
  assert_false(
    validate(parse_cddl("root = uint .size (10..9)").unwrap(), IntegerValue(1L))
    .unwrap()
    .is_valid(),
  )
  assert_true(
    validate_json(parse_cddl("root = tstr .size 3").unwrap(), "\"中\"")
    .unwrap()
    .is_valid(),
  )
  assert_false(
    validate_json(parse_cddl("root = [*uint] .size 1").unwrap(), "[1]")
    .unwrap()
    .is_valid(),
  )
}

///|
test "bounded malformed embedded CBOR and regex inputs never trap" {
  let limits = cddl_limits(max_depth=16, max_tokens=256, max_container_items=64)
  for seed = 1; seed <= 256; seed = seed + 1 {
    let raw : Array[Byte] = []
    for i = 0; i < 24; i = i + 1 {
      raw.push(((seed * 37 + i * seed * 13) % 256).to_byte())
    }
    ignore(decode_cbor(Bytes::from_array(raw), limits~))
    ignore(decode_cbor_sequence(Bytes::from_array(raw), limits~))
    ignore(match_xsd_regex(fuzz_source(seed, seed % 30), "test", limits~))
  }
}
