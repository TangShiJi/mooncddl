///|
test "lexer handles rules, comments, controls, and choices" {
  let source = "reading = { sensor: tstr, value: int } ; comment\nsmall = 0..100 / -1\nname = tstr .size 1"
  let tokens = tokenize(source).unwrap()
  assert_true(tokens.length() > 20)
  assert_eq(tokens[0].kind(), Identifier("reading"))
  assert_eq(tokens[1].kind(), Assign)
  assert_eq(tokens[2].kind(), LBrace)
  assert_eq(tokens[tokens.length() - 1].kind(), EndOfInput)
}

///|
test "lexer decodes strings and hexadecimal byte strings" {
  let tokens = tokenize("a = \"line\\nnext\"\nb = h'00 ff 10'").unwrap()
  assert_eq(tokens[2].kind(), TextLiteral("line\nnext"))
  assert_eq(
    tokens[6].kind(),
    ByteLiteral(Bytes::from_array([0x00, 0xff, 0x10])),
  )
}

///|
test "lexer reports malformed source with a span" {
  let result = tokenize("a = h'0'")
  match result {
    Ok(_) => fail("odd-length hex string should fail")
    Err(error) => {
      assert_eq(error.kind(), LexicalError)
      assert_true(error.span() is Some(_))
    }
  }
}

///|
test "lexer enforces resource limits" {
  let limits = cddl_limits(max_tokens=3)
  let result = tokenize("a = int", limits~)
  match result {
    Ok(_) => fail("token limit should fail")
    Err(error) => assert_eq(error.kind(), ResourceLimit)
  }
}
