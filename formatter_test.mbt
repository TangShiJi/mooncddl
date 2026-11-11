///|
test "canonical formatter is stable and round-trips schemas" {
  let source =
    #|item = { id: uint, ? label: tstr .size 1..20, * tstr => any }
    #|batch = #6.1000([1*10 item])
  let first = parse_cddl(source).unwrap()
  let rendered = format_cddl(first).unwrap()
  let second = parse_cddl(rendered).unwrap()
  assert_eq(format_cddl(second), Ok(rendered))
}

///|
test "formatter escapes text and hexadecimal bytes" {
  let source = "sample = \"line\\nnext\" / h'00ff10'"
  let rendered = format_cddl(parse_cddl(source).unwrap()).unwrap()
  assert_true(rendered.contains("\\n"))
  assert_true(rendered.contains("h'00ff10'"))
}

///|
test "formatter preserves exclusive ranges" {
  let rendered = format_cddl(parse_cddl("percent = 0...101").unwrap()).unwrap()
  assert_eq(rendered, "percent = 0...101\n")
}
