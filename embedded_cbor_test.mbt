///|
test "embedded CBOR accepts one item and rejects trailing or malformed data" {
  let document = parse_cddl("root = bstr .cbor {1: uint}").unwrap()
  assert_true(
    validate(document, bytes_value(b"\xa1\x01\x18\x2a")).unwrap().is_valid(),
  )
  for
    bytes in [
      b"\xa1\x01", b"\xa1\x01\x01\x00", b"\xff", b"\x7f\x61\xff\xff", b"\xf8\x00",
    ] {
    assert_false(validate(document, bytes_value(bytes)).unwrap().is_valid())
  }
  assert_false(
    validate(document, bytes_value(b"\xa1\x01\x61x")).unwrap().is_valid(),
  )
}

///|
test "embedded CBOR sequences become arrays including the empty sequence" {
  let document = parse_cddl("root = bstr .cborseq [* uint]").unwrap()
  assert_true(
    validate(document, bytes_value(b"\x01\x02\x18\xff")).unwrap().is_valid(),
  )
  assert_true(validate(document, bytes_value(b"")).unwrap().is_valid())
  assert_false(
    validate(document, bytes_value(b"\x01\x61x")).unwrap().is_valid(),
  )
}

///|
test "CBOR decoder handles all major types indefinite strings maps and floats" {
  assert_eq(
    decode_cbor(b"\x1b\xff\xff\xff\xff\xff\xff\xff\xff"),
    Ok(UnsignedValue(18446744073709551615UL)),
  )
  assert_eq(
    decode_cbor(b"\x3b\xff\xff\xff\xff\xff\xff\xff\xff"),
    Ok(NegativeValue(18446744073709551615UL)),
  )
  assert_eq(decode_cbor(b"\x5f\x42ab\x41c\xff"), Ok(BytesValue(b"abc")))
  assert_eq(decode_cbor(b"\x7f\x62ab\x61c\xff"), Ok(TextValue("abc")))
  assert_eq(
    decode_cbor(b"\x9f\x01\x02\xff"),
    Ok(ArrayValue([IntegerValue(1L), IntegerValue(2L)])),
  )
  assert_eq(decode_cbor(b"\xf9\x3e\x00"), Ok(FloatValue(1.5)))
  assert_eq(decode_cbor(b"\xfa\x3f\xc0\x00\x00"), Ok(FloatValue(1.5)))
  assert_eq(
    decode_cbor(b"\xfb\x3f\xf8\x00\x00\x00\x00\x00\x00"),
    Ok(FloatValue(1.5)),
  )
  assert_eq(decode_cbor(b"\xf7"), Ok(SimpleValue(23)))
  assert_eq(decode_cbor(b"\xd8\x20\x61x"), Ok(TaggedValue(32L, TextValue("x"))))
  assert_true(decode_cbor(b"\xa2\x01\x02\x01\x03") is Err(_))
  assert_true(
    decode_cbor(b"\x9f\x01\xff", limits=cddl_limits(max_depth=1)) is Ok(_),
  )
  assert_true(
    decode_cbor(b"\x82\x01\x02", limits=cddl_limits(max_container_items=1))
    is Err(_),
  )
}

///|
test "CBOR decoder bounds arbitrary short byte inputs without panicking" {
  for head = 0; head < 256; head = head + 1 {
    ignore(decode_cbor(Bytes::from_array([head.to_byte()])))
    ignore(decode_cbor(Bytes::from_array([head.to_byte(), 0x00, 0xff])))
  }
}
