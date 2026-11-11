///|
test "parser builds a realistic telemetry schema" {
  let source =
    #|reading = {
    #|  sensor: tstr .size 1,
    #|  value: -40..125,
    #|  ? unit: "C" / "F",
    #|  * tstr => any,
    #|}
    #|batch = [1*100 reading]
  let document = parse_cddl(source).unwrap()
  assert_eq(document.root_name(), Some("reading"))
  assert_true(document.lookup("batch") is Some(_))
}

///|
test "parser supports tags, bounded occurrences, and comparisons" {
  let source =
    #|identifier = bstr .size 16
    #|envelope = #6.1001([2*4 identifier, int .ge 0])
  let document = parse_cddl(source).unwrap()
  assert_true(document.lookup("envelope") is Some(_))
}

///|
test "parser rejects duplicate and unknown rules" {
  match parse_cddl("a = int\na = tstr") {
    Ok(_) => fail("duplicate rule should fail")
    Err(error) => assert_eq(error.kind(), DuplicateRule)
  }
  match parse_cddl("a = missing") {
    Ok(_) => fail("unknown reference should fail")
    Err(error) => assert_eq(error.kind(), UnknownRule)
  }
}

///|
test "parser rejects unsupported controls explicitly" {
  match parse_cddl("name = tstr .regexp \"[a-z]+\"") {
    Ok(_) => fail("unsupported control must not be ignored")
    Err(error) => assert_eq(error.kind(), UnsupportedFeature)
  }
}
