///|
fn format_float(value : Double) -> Result[String, CddlError] {
  if value != value {
    return Err(
      cddl_error(
        UnsupportedFeature,
        "NaN has no singleton CDDL number spelling",
      ),
    )
  }
  if value == 1.0 / 0.0 {
    return Ok("1e9999")
  }
  if value == -1.0 / 0.0 {
    return Ok("-1e9999")
  }
  let text = value.to_string()
  Ok(
    if text.contains(".") || text.contains("e") || text.contains("E") {
      text
    } else {
      text + ".0"
    },
  )
}
