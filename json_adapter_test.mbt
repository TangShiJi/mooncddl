///|
test "JSON adapter validates an API request without a second schema language" {
  let schema_source =
    #|request = {
    #|  id: uint,
    #|  title: tstr .size 1..80,
    #|  ? urgent: bool,
    #|}
  let document = parse_cddl(schema_source).unwrap()
  let valid = validate_json(
    document, "{\"id\":42,\"title\":\"restart gateway\",\"urgent\":true}",
  ).unwrap()
  assert_true(valid.is_valid())
  let invalid = validate_json(document, "{\"id\":-1,\"title\":\"\"}").unwrap()
  assert_false(invalid.is_valid())
  assert_eq(invalid.issues().length(), 2)
}

///|
test "JSON adapter preserves integer and floating-point kinds" {
  let value = parse_json_value("[1,1.5,true,null]").unwrap()
  assert_eq(
    value,
    array_value([
      integer_value(1L),
      float_value(1.5),
      bool_value(true),
      null_value(),
    ]),
  )
}

///|
test "JSON adapter rejects invalid and excessive input" {
  match parse_json_value("{") {
    Ok(_) => fail("invalid JSON should fail")
    Err(error) => assert_eq(error.kind(), JsonConversion)
  }
  match parse_json_value("[1,2]", limits=cddl_limits(max_container_items=1)) {
    Ok(_) => fail("container limit should fail")
    Err(error) => assert_eq(error.kind(), ResourceLimit)
  }
}
