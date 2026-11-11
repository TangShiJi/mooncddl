///|
fn main {
  let schema_source =
    #|reading = {
    #|  sensor: tstr .size 1..32,
    #|  value: -40..125,
    #|  ? unit: "C" / "F",
    #|  * tstr => any,
    #|}
  let document = @cddl.parse_cddl(schema_source).unwrap()
  let payload = @cddl.map_value([
    (@cddl.text_value("sensor"), @cddl.text_value("warehouse-a")),
    (@cddl.text_value("value"), @cddl.integer_value(23L)),
    (@cddl.text_value("unit"), @cddl.text_value("C")),
    (@cddl.text_value("sequence"), @cddl.integer_value(100L)),
  ])
  let mut accepted = 0
  for _index = 0; _index < 100000; _index = _index + 1 {
    if @cddl.validate(document, payload).unwrap().is_valid() {
      accepted += 1
    }
  }
  println("validated " + accepted.to_string() + " telemetry values")
}
