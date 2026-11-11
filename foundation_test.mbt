///|
test "value model keeps CBOR-only values" {
  let value = @mooncddl.map_value([
    (@mooncddl.integer_value(1L), @mooncddl.bytes_value(b"\x00\xff")),
    (
      @mooncddl.text_value("kind"),
      @mooncddl.tagged_value(1004L, @mooncddl.text_value("2026-11-11")),
    ),
  ])
  assert_eq(value.kind_name(), "map")
  assert_eq(value.map_entries().unwrap().length(), 2)
  assert_eq(
    value.lookup_text("kind"),
    Some(TaggedValue(1004L, TextValue("2026-11-11"))),
  )
}

///|
test "size counts UTF-8 bytes and container entries" {
  assert_eq(@mooncddl.text_value("月").size(), Some(3))
  assert_eq(@mooncddl.bytes_value(b"abc").size(), Some(3))
  assert_eq(@mooncddl.array_value([NullValue, BoolValue(true)]).size(), Some(2))
}

///|
test "resource limits never become zero or negative" {
  let limits = @mooncddl.cddl_limits(
    max_source_bytes=0,
    max_tokens=-1,
    max_depth=0,
    max_issues=0,
  )
  assert_eq(limits.max_source_bytes(), 1)
  assert_eq(limits.max_tokens(), 1)
  assert_eq(limits.max_depth(), 1)
  assert_eq(limits.max_issues(), 1)
}
