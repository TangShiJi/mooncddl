///|
fn main {
  let source =
    #|create-job = {
    #|  id: uint,
    #|  title: tstr .size 1..80,
    #|  ? priority: 1..5,
    #|}
  let document = @cddl.parse_cddl(source).unwrap()
  let payload = "{\"id\":42,\"title\":\"rebuild search index\",\"priority\":3}"
  let report = @cddl.validate_json(document, payload).unwrap()
  println(
    if report.is_valid() {
      "API payload is valid"
    } else {
      "API payload is invalid"
    },
  )
}
