///|
fn telemetry_schema() -> Schema {
  match
    parse_cddl(
      (
        #|reading = {
        #|  sensor: tstr .size 1..32,
        #|  value: -40..125,
        #|  ? unit: "C" / "F",
        #|}
        #|batch = [1*3 reading]
      ),
    ) {
    Ok(value) => value
    Err(error) => abort(error.message())
  }
}

///|
test "validator accepts and rejects scalar constraints" {
  let document = parse_cddl("temperature = int .ge -40 .le 125").unwrap()
  assert_true(validate(document, integer_value(20L)).unwrap().is_valid())
  let report = validate(document, integer_value(200L)).unwrap()
  assert_false(report.is_valid())
  assert_eq(report.issues()[0].code(), ComparisonFailed)
}

///|
test "validator reports exact map paths and closed-map extras" {
  let document = telemetry_schema()
  let invalid = map_value([
    (text_value("sensor"), text_value("")),
    (text_value("value"), integer_value(200L)),
    (text_value("extra"), bool_value(true)),
  ])
  let report = validate(document, invalid).unwrap()
  assert_false(report.is_valid())
  let paths = report.issues().map(issue => issue.path())
  assert_true(paths.contains("/sensor"))
  assert_true(paths.contains("/value"))
  assert_true(paths.contains("/extra"))
}

///|
test "validator handles repeated arrays and named references" {
  let document = telemetry_schema()
  let reading = map_value([
    (text_value("sensor"), text_value("outdoor")),
    (text_value("value"), integer_value(18L)),
    (text_value("unit"), text_value("C")),
  ])
  let valid_batch = array_value([reading, reading])
  assert_true(
    validate(document, valid_batch, root=Some("batch")).unwrap().is_valid(),
  )
  let invalid_batch = array_value([])
  let report = validate(document, invalid_batch, root=Some("batch")).unwrap()
  assert_false(report.is_valid())
  assert_eq(report.issues()[0].code(), TooFewItems)
}

///|
test "validator supports CBOR tags and non-string map keys" {
  let document = parse_cddl("message = #6.1001({ 1 => bstr .size 2 })").unwrap()
  let value = tagged_value(
    1001L,
    map_value([
      (integer_value(1L), bytes_value(Bytes::from_array([0xca, 0xfe]))),
    ]),
  )
  assert_true(validate(document, value).unwrap().is_valid())
}

///|
test "validator caps recursion and issue counts" {
  let recursive = parse_cddl("node = [int, ? node]").unwrap()
  let nested = array_value([
    integer_value(1L),
    array_value([integer_value(2L), array_value([integer_value(3L)])]),
  ])
  let report = validate(recursive, nested, limits=cddl_limits(max_depth=4)).unwrap()
  assert_false(report.is_valid())
  assert_true(report.issues().length() <= 100)
}
