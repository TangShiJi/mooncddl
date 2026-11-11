///|
fn fuzz_source(seed : Int32, length : Int32) -> String {
  let alphabet = "abcdefghijklmnopqrstuvwxyz0123456789={}[](),?*+/#.;:\"'_- \n".to_array()
  let output : Array[Char] = []
  let mut state = seed
  for _index = 0; _index < length; _index = _index + 1 {
    state = (state * 251 + 17) % 65521
    output.push(alphabet[state % alphabet.length()])
  }
  String::from_array(output)
}

///|
test "parser survives deterministic malformed-input corpus" {
  let limits = cddl_limits(
    max_source_bytes=512,
    max_tokens=256,
    max_rules=32,
    max_depth=24,
    max_container_items=64,
    max_issues=8,
  )
  for seed = 1; seed <= 500; seed = seed + 1 {
    let source = fuzz_source(seed, 20 + seed % 100)
    match parse_cddl(source, limits~) {
      Ok(document) =>
        match format_cddl(document) {
          Ok(formatted) => ignore(parse_cddl(formatted, limits~))
          Err(_) => ()
        }
      Err(_) => ()
    }
  }
}

///|
test "generated numeric schemas retain validation invariants" {
  for index = 0; index < 200; index = index + 1 {
    let lower = index - 100
    let upper = lower + 10
    let source = "value = " + lower.to_string() + ".." + upper.to_string()
    let document = parse_cddl(source).unwrap()
    let example = generate_example(document).unwrap()
    assert_true(validate(document, example).unwrap().is_valid())
    assert_false(
      validate(document, integer_value((upper + 1).to_int64()))
      .unwrap()
      .is_valid(),
    )
  }
}
