///|
test "RFC 8610 size is a capacity bound for unsigned integers" {
  let document = parse_cddl("sample = uint .size 3").unwrap()
  for number in [0L, 1L, 255L, 16777215L] {
    assert_true(validate(document, integer_value(number)).unwrap().is_valid())
  }
  assert_false(validate(document, integer_value(16777216L)).unwrap().is_valid())
  assert_false(validate(document, integer_value(-1L)).unwrap().is_valid())
  let zero = parse_cddl("sample = uint .size 0").unwrap()
  assert_true(validate(zero, integer_value(0L)).unwrap().is_valid())
  assert_false(validate(zero, integer_value(1L)).unwrap().is_valid())
}

///|
test "RFC bits checks least significant bit numbering for uint and bytes" {
  let document = parse_cddl(
    "root = uint .bits permissions\npermissions = &(r: 2, w: 1, x: 0)",
  ).unwrap()
  assert_true(validate(document, integer_value(7L)).unwrap().is_valid())
  assert_true(validate(document, integer_value(0L)).unwrap().is_valid())
  assert_false(validate(document, integer_value(8L)).unwrap().is_valid())
  let bytes = parse_cddl("root = bstr .bits (0 / 8)").unwrap()
  assert_true(validate(bytes, bytes_value(b"\x01\x01")).unwrap().is_valid())
  assert_false(validate(bytes, bytes_value(b"\x00\x02")).unwrap().is_valid())
}

///|
test "RFC default rejects explicitly encoded default instead of injecting data" {
  let document = parse_cddl("root = { ? enabled: bool .default false }").unwrap()
  assert_true(validate_json(document, "{}").unwrap().is_valid())
  assert_true(validate_json(document, "{\"enabled\":true}").unwrap().is_valid())
  assert_false(
    validate_json(document, "{\"enabled\":false}").unwrap().is_valid(),
  )
}

///|
test "integer comparisons do not round adjacent Int64 values" {
  let document = parse_cddl(
    "root = int .lt boundary\nboundary = 9007199254740993",
  ).unwrap()
  assert_true(
    validate(document, integer_value(9007199254740992L)).unwrap().is_valid(),
  )
  assert_false(
    validate(document, integer_value(9007199254740993L)).unwrap().is_valid(),
  )
}

///|
test "unplugged sockets have standard empty type and empty group behavior" {
  let empty_type = parse_cddl("root = $missing").unwrap()
  assert_false(validate(empty_type, integer_value(1L)).unwrap().is_valid())
  let empty_group = parse_cddl("root = [$$missing, uint]").unwrap()
  assert_true(validate_json(empty_group, "[1]").unwrap().is_valid())
}

///|
test "cut prevents wrong typed map value from escaping through wildcard" {
  let document = parse_cddl("root = { ? name: tstr, * tstr => any }").unwrap()
  assert_true(
    validate_json(document, "{\"name\":\"Ada\",\"extra\":1}")
    .unwrap()
    .is_valid(),
  )
  assert_false(validate_json(document, "{\"name\":1}").unwrap().is_valid())
}

///|
test "ambiguous and empty group searches stop at explicit resource limits" {
  let document = parse_cddl("root = [* (), uint]").unwrap()
  assert_true(validate_json(document, "[1]").unwrap().is_valid())
  let limited = parse_cddl("root = [* uint, * uint, * uint, tstr]").unwrap()
  let report = validate_json(
    limited,
    "[1,2,3,4,5,6]",
    limits=cddl_limits(max_tokens=10),
  ).unwrap()
  assert_false(report.is_valid())
  assert_true(report.issues().any(issue => issue.code() == RecursionLimit))
}

///|
test "large requested generated containers fail before allocating" {
  let document = parse_cddl("root = [1000000000* uint]").unwrap()
  assert_true(
    generate_example(document, limits=cddl_limits(max_container_items=100))
    is Err(_),
  )
}
