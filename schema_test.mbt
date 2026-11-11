///|
test "schema preserves rules, entries, and cardinality" {
  let reading = map_schema([
    group_entry(primitive(TextType), key=Some(literal(text_value("sensor")))),
    group_entry(
      primitive(IntType),
      key=Some(literal(text_value("value"))),
      occurrence=optional(),
    ),
  ])
  let document = schema([rule("reading", reading, source_span(0, 7, 1, 1))])
  assert_eq(document.root_name(), Some("reading"))
  assert_eq(document.lookup("reading"), Some(reading))
  assert_eq(document.lookup("missing"), None)
}

///|
test "predefined names and controls are explicit" {
  assert_eq(primitive_from_name("tstr"), Some(TextType))
  assert_eq(primitive_from_name("string"), None)
  assert_eq(control_from_name("size"), Some(SizeControl))
  assert_eq(control_from_name("regexp"), None)
}
