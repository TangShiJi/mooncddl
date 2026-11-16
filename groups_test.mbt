///|
test "Appendix A occurrences are greedy and never give back consumed values" {
  for
    source in [
      "a = [* uint, uint]", "a = [? uint, uint]", "a = [*2 uint, uint]",
    ] {
    let document = parse_cddl(source).unwrap()
    assert_false(validate_json(document, "[1]").unwrap().is_valid(), msg=source)
    assert_false(validate_json(document, "[]").unwrap().is_valid())
  }
  let document = parse_cddl("a = [*2 uint, uint]").unwrap()
  assert_true(validate_json(document, "[1,2,3]").unwrap().is_valid())
  assert_false(validate_json(document, "[1,2,3,4]").unwrap().is_valid())
  let priority = parse_cddl("root = [(uint // uint, tstr)]").unwrap()
  assert_false(validate_json(priority, "[1,\"x\"]").unwrap().is_valid())
}

///|
test "group alternatives and repeated named groups consume complete tuples" {
  let source = "root = [1*2 pair]\npair = (uint, tstr)"
  let document = parse_cddl(source).unwrap()
  assert_true(validate_json(document, "[1,\"a\",2,\"b\"]").unwrap().is_valid())
  assert_false(validate_json(document, "[1,\"a\",2]").unwrap().is_valid())
  let alternatives = parse_cddl("root = [ (1, uint) // (2, tstr) ]").unwrap()
  assert_true(validate_json(alternatives, "[1,42]").unwrap().is_valid())
  assert_true(validate_json(alternatives, "[2,\"ok\"]").unwrap().is_valid())
  assert_false(validate_json(alternatives, "[2,42]").unwrap().is_valid())
}

///|
test "generic binding is scoped and supports nested applications" {
  let source = "root = pair<uint, pair<tstr,bool>>\npair<a,b> = [a,b]"
  let document = parse_cddl(source).unwrap()
  assert_true(validate_json(document, "[1,[\"ok\",true]]").unwrap().is_valid())
  assert_false(validate_json(document, "[1,[false,true]]").unwrap().is_valid())
  let formatted = format_cddl(document).unwrap()
  assert_eq(format_cddl(parse_cddl(formatted).unwrap()).unwrap(), formatted)
}

///|
test "unwrap and group enumeration have different value semantics" {
  let document = parse_cddl(
    "root = [~point, &colors]\npoint = [number, number]\ncolors = (red: 1, blue: 2)",
  ).unwrap()
  assert_true(validate_json(document, "[0,1,2]").unwrap().is_valid())
  assert_false(validate_json(document, "[[0,1],2]").unwrap().is_valid())
  assert_false(validate_json(document, "[0,1,3]").unwrap().is_valid())
}

///|
test "incremental type group and socket definitions retain alternatives" {
  let document = parse_cddl("root = [$item]\n$item /= uint\n$item /= tstr").unwrap()
  assert_true(validate_json(document, "[1]").unwrap().is_valid())
  assert_true(validate_json(document, "[\"ok\"]").unwrap().is_valid())
  assert_false(validate_json(document, "[true]").unwrap().is_valid())
  let groups = parse_cddl("root = [g]\ng = (1, uint)\ng //= (2, tstr)").unwrap()
  assert_true(validate_json(groups, "[2,\"ok\"]").unwrap().is_valid())
}

///|
test "maps match typed keys by value without dependence on input order" {
  let document = parse_cddl("root = { uint => tstr, uint => uint }").unwrap()
  let one = map_value([
    (integer_value(1L), integer_value(2L)),
    (integer_value(3L), text_value("ok")),
  ])
  let two = map_value([
    (integer_value(3L), text_value("ok")),
    (integer_value(1L), integer_value(2L)),
  ])
  assert_true(validate(document, one).unwrap().is_valid())
  assert_true(validate(document, two).unwrap().is_valid())
  let keys = parse_cddl("root = {1: uint, \"name\": tstr}").unwrap()
  assert_true(
    validate(
      keys,
      map_value([
        (integer_value(1L), integer_value(2L)),
        (text_value("name"), text_value("ok")),
      ]),
    )
    .unwrap()
    .is_valid(),
  )
}
