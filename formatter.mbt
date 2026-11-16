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
fn hex_nibble(value : Int32) -> String {
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
    UnsignedValue(value) => Ok(value.to_string())
    NegativeValue(value) =>
      Ok(
        if value == 18446744073709551615UL {
          "-18446744073709551616"
        } else {
          "-" + (value + 1UL).to_string()
        },
      )
    SimpleValue(value) => Ok("#7." + value.to_string())
    EncodedFloat(_, value) => format_float(value)
    TextValue(value) => Ok(escape_cddl_text(value))
    BytesValue(value) => Ok(format_bytes(value))
    FloatValue(value) => format_float(value)
    ArrayValue(_) | MapValue(_) | TaggedValue(_, _) | WideTagValue(_, _) =>
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
    BitsControl => "bits"
    DefaultControl => "default"
    TagContentControl => "tag-content"
    CborControl => "cbor"
    CborSequenceControl => "cborseq"
    RegexpControl => "regexp"
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
    MajorSchema(major, argument) =>
      Ok(
        "#" +
        major.to_string() +
        (match argument {
          Some(value) => "." + value.to_string()
          None => ""
        }),
      )
    ValueRange(lower, upper, exclusive) =>
      match (format_literal(lower), format_literal(upper)) {
        (Ok(a), Ok(b)) => Ok(a + (if exclusive { "..." } else { ".." }) + b)
        (Err(error), _) | (_, Err(error)) => Err(error)
      }
    DynamicRange(lower, upper, exclusive) =>
      match (format_expression(lower), format_expression(upper)) {
        (Ok(a), Ok(b)) => Ok(a + (if exclusive { " ... " } else { " .. " }) + b)
        (Err(error), _) | (_, Err(error)) => Err(error)
      }
    Application(name, arguments) => {
      let parts : Array[String] = []
      for argument in arguments {
        match format_expression(argument) {
          Ok(value) => parts.push(value)
          Err(error) => return Err(error)
        }
      }
      Ok(name + "<" + parts.join(", ") + ">")
    }
    Unwrap(body) | Enumeration(body) =>
      match format_expression(body) {
        Ok(value) =>
          Ok((if expression is Unwrap(_) { "~" } else { "&" }) + value)
        Err(error) => Err(error)
      }
    GroupSchema(alternatives) => {
      let groups : Array[String] = []
      for entries in alternatives {
        match format_group_entries(entries) {
          Ok(value) => groups.push(value)
          Err(error) => return Err(error)
        }
      }
      Ok("(" + groups.join(" // ") + ")")
    }
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
      if operator == TagContentControl {
        match (format_expression(target), format_expression(argument)) {
          (Ok(left), Ok(right)) => return Ok(left + "(" + right + ")")
          (Err(error), _) | (_, Err(error)) => return Err(error)
        }
      }
      let left = match format_expression(target) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      let right = match format_expression(argument) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      Ok("(" + left + ") ." + control_name(operator) + " (" + right + ")")
    }
  }
}

///|
fn format_group(
  entries : Array[GroupEntry],
  is_map : Bool,
) -> Result[String, CddlError] {
  match format_group_entries(entries) {
    Ok(body) =>
      Ok(
        (if is_map { "{ " } else { "[ " }) +
        body +
        (if is_map { " }" } else { " ]" }),
      )
    Err(error) => Err(error)
  }
}

///|
fn format_group_entries(
  entries : Array[GroupEntry],
) -> Result[String, CddlError] {
  let output : Array[String] = []
  for entry in entries {
    let prefix = format_occurrence(entry.occurrence())
    let value = match format_expression(entry.value()) {
      Ok(formatted) => formatted
      Err(error) => return Err(error)
    }
    if entry.key() is Some(_) {
      let key = match entry.key() {
        Some(expression) =>
          match format_expression(expression) {
            Ok(formatted) => formatted
            Err(error) => return Err(error)
          }
        None => "any"
      }
      output.push(
        prefix + key + (if entry.is_cut() { " ^=> " } else { " => " }) + value,
      )
    } else {
      output.push(prefix + value)
    }
  }
  Ok(output.join(", "))
}

///|
/// Emit a stable, parseable CDDL representation. Formatting a parsed schema
/// twice produces identical text, making it suitable for review and CI diffs.
pub fn format_cddl(document : Schema) -> Result[String, CddlError] {
  let output : Array[String] = []
  for item in document.rules() {
    match format_expression(item.value()) {
      Ok(value) =>
        output.push(
          item.name() +
          (if item.parameters().length() == 0 {
            ""
          } else {
            "<" + item.parameters().join(", ") + ">"
          }) +
          " = " +
          value,
        )
      Err(error) => return Err(error)
    }
  }
  Ok(output.join("\n") + "\n")
}
