///|
fn main raise {
  let source =
    #|event = [~header, payload<uint>]
    #|header = [version: 1, kind: &kinds]
    #|kinds = (telemetry: 1, heartbeat: 2)
    #|payload<T> = { values: [1*4 T], ? flags: uint .bits &(r: 2, w: 1, x: 0) }
  let syntax = @cddl.check_standard_syntax(source).unwrap()
  assert_eq(syntax.rule_names().length(), 4)
  let document = @cddl.parse_cddl(source).unwrap()
  let valid = "[1,1,{\"values\":[10,20],\"flags\":3}]"
  let invalid = "[1,9,{\"values\":[10,20],\"flags\":8}]"
  assert_true(@cddl.validate_json(document, valid).unwrap().is_valid())
  assert_false(@cddl.validate_json(document, invalid).unwrap().is_valid())
  println(
    "standard contract: syntax, valid event, rejected invalid event passed",
  )
}
