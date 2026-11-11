///|
fn json_to_cddl(
  input : Json,
  limits : CddlLimits,
  depth : Int,
) -> Result[CddlValue, CddlError] {
  if depth > limits.max_depth() {
    return Err(cddl_error(ResourceLimit, "JSON nesting exceeds max_depth"))
  }
  match input {
    Null => Ok(null_value())
    True => Ok(bool_value(true))
    False => Ok(bool_value(false))
    Number(number, ..) =>
      if number == number.floor() &&
        number >= -9007199254740991.0 &&
        number <= 9007199254740991.0 {
        Ok(integer_value(number.to_int64()))
      } else {
        Ok(float_value(number))
      }
    String(value) => Ok(text_value(value))
    Array(items) => {
      if items.length() > limits.max_container_items() {
        return Err(
          cddl_error(ResourceLimit, "JSON array exceeds max_container_items"),
        )
      }
      let output : Array[CddlValue] = []
      for item in items {
        match json_to_cddl(item, limits, depth + 1) {
          Ok(value) => output.push(value)
          Err(error) => return Err(error)
        }
      }
      Ok(array_value(output))
    }
    Object(entries) => {
      if entries.length() > limits.max_container_items() {
        return Err(
          cddl_error(ResourceLimit, "JSON object exceeds max_container_items"),
        )
      }
      let output : Array[(CddlValue, CddlValue)] = []
      for key, item in entries {
        match json_to_cddl(item, limits, depth + 1) {
          Ok(value) => output.push((text_value(key), value))
          Err(error) => return Err(error)
        }
      }
      Ok(map_value(output))
    }
  }
}

///|
/// Parse JSON into the format-neutral value model. JSON integers that can be
/// represented exactly by IEEE-754 are retained as integers; other numbers
/// remain floating-point values instead of being silently truncated.
#warnings("-deprecated")
pub fn parse_json_value(
  source : String,
  limits? : CddlLimits = cddl_limits(),
) -> Result[CddlValue, CddlError] {
  if @utf8.encode(source[:]).length() > limits.max_source_bytes() {
    return Err(
      cddl_error(ResourceLimit, "JSON source exceeds max_source_bytes"),
    )
  }
  let parsed = try
    @json.parse(source[:], max_nesting_depth=limits.max_depth())
  catch {
    _ => return Err(cddl_error(JsonConversion, "input is not valid JSON"))
  } noraise {
    value => value
  }
  json_to_cddl(parsed, limits, 0)
}

///|
/// Convenience entry point for applications that receive JSON text.
pub fn validate_json(
  document : Schema,
  source : String,
  root? : String? = None,
  limits? : CddlLimits = cddl_limits(),
) -> Result[ValidationReport, CddlError] {
  let value = match parse_json_value(source, limits~) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  validate(document, value, root~, limits~)
}
