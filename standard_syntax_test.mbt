///|
test "Appendix B productions accept independent standard syntax examples" {
  let cases : Array[(String, String)] = [
    ("rules and whitespace", "a = uint b = tstr\nc = [a,b] ; comment\n"),
    ("identifiers", "a.b--c = @x\n@x = _thing\n_thing = uint"),
    ("type extension", "answer = uint\nanswer /= tstr"),
    ("group extension", "g = (a: uint)\ng //= (b: tstr)"),
    (
      "socket plug", "root = $type / [$$group]\n$type /= uint\n$$group //= (uint)",
    ),
    (
      "generic parameters and arguments", "root = pair<uint,tstr>\npair<a,b> = [a,b]",
    ),
    ("type choice and parentheses", "root = (uint / tstr) / nil"),
    ("closed and half open ranges", "a = 1..10 b = -1.5...1.5"),
    (
      "control grammar", "a = tstr .regexp \"[a-z]+\" b = uint .bits bits\nbits = (flag: 0)",
    ),
    ("arrays maps empty groups", "a = [] b = {} c = [// uint // tstr]"),
    ("optional comma", "a = [uint tstr ? bool,]"),
    ("group choices", "a = [(1, uint) // (2, tstr)]"),
    (
      "member key forms", "a = {name: tstr, \"key\": uint, 1: bool, uint ^=> tstr}",
    ),
    (
      "occurrence forms", "a = [? uint, + tstr, * bool, *3 uint, 2* uint, 2*5 uint]",
    ),
    ("unwrap", "a = [~point] point = [number,number]"),
    ("enumeration", "a = &colors colors = (red: 1, blue: 2) b = &(x: 3, y: 4)"),
    ("tag optional number", "a = #6.18([bstr]) b = #6(any)"),
    ("major and additional information", "a = # b = #0 c = #7.25 d = #6.123"),
    (
      "unsigned lexical range", "a = 18446744073709551615 b = -18446744073709551616",
    ),
    ("integer bases", "a = 0xff b = 0b101 c = -42"),
    ("decimal floats", "a = 1.0 b = 1e+3 c = -2.5e-2"),
    ("hexadecimal floats", "a = 0x1.8p+1 b = -0x1p-2"),
    ("byte strings", "a = 'text' b = h'CA FE' c = b64'AQID'"),
    ("text escapes", "a = \"a\\\"b\\\\c\\u0041\""),
    (
      "extension controls are syntax", "a = tstr .abnf \"rule\" b = bstr .custom other",
    ),
  ]
  for (name, source) in cases {
    assert_true(check_standard_syntax(source) is Ok(_), msg=name)
  }
}

///|
test "Appendix B malformed syntax is rejected rather than partially consumed" {
  let cases = [
    "", "a", "a =", "a == uint", "a = [", "a = {name:}", "a = pair<>", "pair<> = uint",
    "a = pair<uint,>", "a = uint /", "a = [uint /// tstr]", "a = #6.1(uint", "a = #12",
    "a = 0x", "a = 0b2", "a = 01", "a = 1.", "a = 1e+", "a = 0x1.2", "a = \"unterminated",
    "a = h'00", "a = ~[uint]", "a = &uint<>", "a = uint trailing", "a = {uint ^ tstr}",
    "a = uint .size", "a = [1**3 uint]",
  ]
  for source in cases {
    assert_true(check_standard_syntax(source) is Err(_), msg=source)
  }
}

///|
test "syntax and semantic validation are distinct contracts" {
  let source = "data = bstr .custom uint"
  let syntax = check_standard_syntax(source).unwrap()
  assert_true(syntax.features().contains("control:custom"))
  assert_eq(syntax.rule_names(), ["data"])
  assert_eq(syntax.source(), source)
  // A successful grammar check must never silently enable an unimplemented
  // control in the runtime parser.
  assert_true(parse_cddl(source) is Err(_))
  assert_true(check_standard_syntax("a = nonexistent") is Ok(_))
  assert_true(parse_cddl("a = nonexistent") is Err(_))
}

///|
test "standard grammar parser enforces resource limits" {
  assert_true(
    check_standard_syntax("a = [uint]", limits=cddl_limits(max_depth=2))
    is Err(_),
  )
  assert_true(
    check_standard_syntax("a=uint b=tstr", limits=cddl_limits(max_rules=1))
    is Err(_),
  )
  assert_true(
    check_standard_syntax("a = uint", limits=cddl_limits(max_source_bytes=2))
    is Err(_),
  )
}
