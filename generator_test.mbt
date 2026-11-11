///|
test "generator creates a validated minimal API request" {
  let document = parse_cddl(
    (
      #|request = { id: uint, title: tstr, ? urgent: bool }
    ),
  ).unwrap()
  let value = generate_example(document).unwrap()
  assert_true(validate(document, value).unwrap().is_valid())
  assert_eq(value.lookup_text("id"), Some(integer_value(0L)))
  assert_eq(value.lookup_text("urgent"), None)
}

///|
test "generator handles ranges, repetitions, and tags" {
  let document = parse_cddl("packet = #6.1001([2*4 1..10])").unwrap()
  let value = generate_example(document).unwrap()
  assert_eq(
    value,
    tagged_value(1001L, array_value([integer_value(1L), integer_value(1L)])),
  )
  assert_true(validate(document, value).unwrap().is_valid())
}

///|
test "generator rejects required infinite recursion" {
  let document = parse_cddl("node = [node]").unwrap()
  match generate_example(document) {
    Ok(_) => fail("required recursion has no finite witness")
    Err(error) => assert_eq(error.kind(), RecursiveReference)
  }
}
