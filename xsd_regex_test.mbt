///|
test "XSD regexp preserves its dialect rather than PCRE anchor semantics" {
  let cases : Array[(String, String, Bool)] = [
    ("[a-z]+", "abc", true),
    ("[a-z]+", "x1", false),
    ("^a$", "a", false),
    ("^a$", "^a$", true),
    ("a.b", "a\nb", false),
    ("a.b", "a\rb", false),
    ("a(b|c){2,3}", "abcb", true),
    ("a(b|c){2,3}", "ab", false),
    ("(a?){3}", "a", true),
    ("(a?)*", "", true),
    ("[a-z-[aeiou]]+", "bcdf", true),
    ("[a-z-[aeiou]]+", "bad", false),
    ("[^a-z-[0-9]]+", "!?", true),
    ("[^a-z-[0-9]]+", "9", false),
    ("\\p{L}+", "中文é", true),
    ("\\p{L}+", "123", false),
    ("\\d+", "١٢٣", true),
    ("\\D+", "abc", true),
    ("\\p{IsBasicLatin}+", "abc", true),
    ("\\p{IsBasicLatin}+", "中文", false),
    ("\\i\\c*", "名:字-1", true),
    ("\\i\\c*", "1name", false),
    ("\\w+", "符号+", true),
    ("\\s+", " \t\n\r", true),
    ("a{2,}", "aaaa", true),
    ("a{2}", "aa", true),
  ]
  for (pattern, input, expected) in cases {
    assert_eq(
      match_xsd_regex(pattern, input),
      Ok(expected),
      msg=pattern + ":" + input,
    )
  }
}

///|
test "XSD malformed expressions and unknown Unicode properties fail" {
  for
    pattern in [
      "[", "[]", "[z-a]", "a{3,1}", "a{", "(", "a**", "\\p{Unknown}", "(?=a)", "\\x41",
    ] {
    assert_true(match_xsd_regex(pattern, "a") is Err(_), msg=pattern)
  }
}

///|
test "standard regexp control validates and reports failures" {
  let document = parse_cddl(
    "root = tstr .regexp pattern pattern = \"[a-z-[aeiou]]+\"",
  ).unwrap()
  assert_true(validate(document, text_value("bcdf")).unwrap().is_valid())
  assert_false(validate(document, text_value("bad")).unwrap().is_valid())
  assert_true(
    match_xsd_regex(
      "(a|aa)*b",
      "aaaaaaaaaaaa",
      limits=cddl_limits(max_tokens=10),
    )
    is Err(_),
  )
}
