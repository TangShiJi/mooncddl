///|
fn main {
  let source =
    #|telemetry = #6.1001({
    #|  1 => bstr .size 8,
    #|  2 => -40..125,
    #|  ? 3 => tstr .size 1..12,
    #|})
  let document = @cddl.parse_cddl(source).unwrap()
  let payload = @cddl.tagged_value(
    1001L,
    @cddl.map_value([
      (
        @cddl.integer_value(1L),
        @cddl.bytes_value(
          Bytes::from_array([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]),
        ),
      ),
      (@cddl.integer_value(2L), @cddl.integer_value(23L)),
      (@cddl.integer_value(3L), @cddl.text_value("warehouse-a")),
    ]),
  )
  let report = @cddl.validate(document, payload).unwrap()
  println(
    if report.is_valid() {
      "CBOR telemetry is valid"
    } else {
      "CBOR telemetry is invalid"
    },
  )
}
