///|
test "RFC 8610 core examples validate expected JSON values" {
  let cases : Array[(String, String, Bool)] = [
    (
      "person = { name: tstr, age: 0..150 }", "{\"name\":\"Ada\",\"age\":37}", true,
    ),
    (
      "person = { name: tstr, age: 0..150 }", "{\"name\":\"Ada\",\"age\":151}", false,
    ),
    ("point = [number, number]", "[1.5,-2]", true),
    ("point = [number, number]", "[1]", false),
    ("answer = 42 / \"unknown\"", "42", true),
    ("answer = 42 / \"unknown\"", "false", false),
    ("labels = [* tstr]", "[\"a\",\"b\",\"c\"]", true),
    ("closed = { enabled: bool }", "{\"enabled\":true,\"extra\":0}", false),
  ]
  for item in cases {
    let (schema_source, json_source, expected) = item
    let document = parse_cddl(schema_source).unwrap()
    let actual = validate_json(document, json_source).unwrap().is_valid()
    assert_eq(actual, expected)
  }
}

///|
test "CDDL controls compose without being silently skipped" {
  let document = parse_cddl(
    (
      #|token = tstr .size 4..12
      #|level = int .ge 1 .le 5
      #|mode = tstr .ne "disabled"
    ),
  ).unwrap()
  assert_true(
    validate(document, text_value("abcd"), root=Some("token"))
    .unwrap()
    .is_valid(),
  )
  assert_false(
    validate(document, text_value("abc"), root=Some("token"))
    .unwrap()
    .is_valid(),
  )
  assert_true(
    validate(document, integer_value(3L), root=Some("level"))
    .unwrap()
    .is_valid(),
  )
  assert_false(
    validate(document, text_value("disabled"), root=Some("mode"))
    .unwrap()
    .is_valid(),
  )
}

///|
test "canonical formatting is idempotent across representative grammar" {
  let sources : Array[String] = [
    "value = int / tstr / nil", "map = { 1 => bstr, ? 2 => bool, * tstr => any }",
    "array = [2*5 uint, ? tstr]", "tagged = #6.18([bstr, bstr])", "bounded = tstr .size 1..64",
  ]
  for source in sources {
    let once_formatted = format_cddl(parse_cddl(source).unwrap()).unwrap()
    let twice_formatted = format_cddl(parse_cddl(once_formatted).unwrap()).unwrap()
    assert_eq(twice_formatted, once_formatted)
  }
}
