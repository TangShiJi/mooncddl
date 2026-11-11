///|
fn main {
  let source =
    #|identifier = bstr .size 16
    #|record = { id: identifier, sequence: uint, ? note: tstr }
    #|batch = [1*5 record]
  let document = @cddl.parse_cddl(source).unwrap()
  let example = @cddl.generate_example(document, root=Some("batch")).unwrap()
  let checked = @cddl.validate(document, example, root=Some("batch")).unwrap()
  println("generated " + example.describe())
  println(
    if checked.is_valid() {
      "self-check passed"
    } else {
      "self-check failed"
    },
  )
}
