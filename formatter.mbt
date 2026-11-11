///|
fn escape_cddl_text(value : String) -> String {
  let output : Array[String] = ["\""]
  for char in value {
    output.push(
      match char {
        '"' => "\\\""
        '\\' => "\\\\"
        '\n' => "\\n"
        '\r' => "\\r"
        '\t' => "\\t"
        '\b' => "\\b"
        '\f' => "\\f"
        _ => char.to_string()
      },
    )
  }
  output.push("\"")
  output.join("")
}

///|
fn hex_nibble(value : Int) -> String {
  "0123456789abcdef"[value:value + 1].to_owned()
}

///|
fn format_bytes(value : Bytes) -> String {
  let output : Array[String] = ["h'"]
  for byte in value {
    let number = byte.to_int()
    output.push(hex_nibble((number >> 4) & 0x0f))
    output.push(hex_nibble(number & 0x0f))
  }
  output.push("'")
  output.join("")
}

///|
fn format_literal(value : CddlValue) -> Result[String, CddlError] {
  match value {
    NullValue => Ok("null")
    BoolValue(value) => Ok(value.to_string())
    IntegerValue(value) => Ok(value.to_string())
    TextValue(value) => Ok(escape_cddl_text(value))
    BytesValue(value) => Ok(format_bytes(value))
    FloatValue(_) =>
      Err(
        cddl_error(
          UnsupportedFeature,
          "canonical formatting of floating-point literals is not supported",
        ),
      )
    ArrayValue(_) | MapValue(_) | TaggedValue(_, _) =>
      Err(
        cddl_error(
          UnsupportedFeature,
          "container values cannot be used as CDDL literals",
        ),
      )
  }
}

///|
fn primitive_name(value : PrimitiveType) -> String {
  match value {
    AnyType => "any"
    BoolType => "bool"
    NilType => "nil"
    UintType => "uint"
    NintType => "nint"
    IntType => "int"
    FloatType => "float"
    NumberType => "number"
    TextType => "tstr"
    BytesType => "bstr"
    ArrayTypeName => "array"
    MapTypeName => "map"
  }
}

///|
fn control_name(value : ControlOperator) -> String {
  match value {
    SizeControl => "size"
    LessThanControl => "lt"
    LessOrEqualControl => "le"
    GreaterThanControl => "gt"
    GreaterOrEqualControl => "ge"
    EqualControl => "eq"
    NotEqualControl => "ne"
    AndControl => "and"
    WithinControl => "within"
  }
}

///|
fn format_occurrence(value : Occurrence) -> String {
  match (value.min(), value.max()) {
    (1, Some(1)) => ""
    (0, Some(1)) => "? "
    (0, None) => "* "
    (1, None) => "+ "
    (minimum, Some(maximum)) =>
      minimum.to_string() + "*" + maximum.to_string() + " "
    (minimum, None) => minimum.to_string() + "* "
  }
}

///|
fn format_expression(expression : TypeExpr) -> Result[String, CddlError] {
  match expression {
    Primitive(value) => Ok(primitive_name(value))
    Literal(value) => format_literal(value)
    Reference(name) => Ok(name)
    Choice(alternatives) => {
      let output : Array[String] = []
      for alternative in alternatives {
        match format_expression(alternative) {
          Ok(value) => output.push(value)
          Err(error) => return Err(error)
        }
      }
      Ok(output.join(" / "))
    }
    IntegerRange(lower, upper, exclusive) =>
      Ok(
        lower.to_string() +
        (if exclusive { "..." } else { ".." }) +
        upper.to_string(),
      )
    ArraySchema(entries) => format_group(entries, false)
    MapSchema(entries) => format_group(entries, true)
    TaggedSchema(tag, value) =>
      match format_expression(value) {
        Ok(nested) => Ok("#6." + tag.to_string() + "(" + nested + ")")
        Err(error) => Err(error)
      }
    Controlled(target, operator, argument) => {
      let left = match format_expression(target) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      let right = match format_expression(argument) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      Ok(left + " ." + control_name(operator) + " " + right)
    }
  }
}

///|
fn format_group(
  entries : Array[GroupEntry],
  is_map : Bool,
) -> Result[String, CddlError] {
  let output : Array[String] = []
  for entry in entries {
    let prefix = format_occurrence(entry.occurrence())
    let value = match format_expression(entry.value()) {
      Ok(formatted) => formatted
      Err(error) => return Err(error)
    }
    if is_map {
      let key = match entry.key() {
        Some(expression) =>
          match format_expression(expression) {
            Ok(formatted) => formatted
            Err(error) => return Err(error)
          }
        None => "any"
      }
      output.push(prefix + key + " => " + value)
    } else {
      output.push(prefix + value)
    }
  }
  let (open, close) = if is_map { ("{ ", " }") } else { ("[ ", " ]") }
  if output.length() == 0 {
    Ok(if is_map { "{}" } else { "[]" })
  } else {
    Ok(open + output.join(", ") + close)
  }
}

///|
/// Emit a stable, parseable CDDL representation. Formatting a parsed schema
/// twice produces identical text, making it suitable for review and CI diffs.
pub fn format_cddl(document : Schema) -> Result[String, CddlError] {
  let output : Array[String] = []
  for item in document.rules() {
    match format_expression(item.value()) {
      Ok(value) => output.push(item.name() + " = " + value)
      Err(error) => return Err(error)
    }
  }
  Ok(output.join("\n") + "\n")
}
