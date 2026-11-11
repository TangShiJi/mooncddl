///|
/// Format-neutral data model covering the JSON data model plus CBOR byte
/// strings, non-string map keys, tags, and floating-point values.
pub(all) enum CddlValue {
  NullValue
  BoolValue(Bool)
  IntegerValue(Int64)
  FloatValue(Double)
  TextValue(String)
  BytesValue(Bytes)
  ArrayValue(Array[CddlValue])
  MapValue(Array[(CddlValue, CddlValue)])
  TaggedValue(Int64, CddlValue)
} derive(Debug, Eq)

///|
pub fn null_value() -> CddlValue {
  NullValue
}

///|
pub fn bool_value(value : Bool) -> CddlValue {
  BoolValue(value)
}

///|
pub fn integer_value(value : Int64) -> CddlValue {
  IntegerValue(value)
}

///|
pub fn float_value(value : Double) -> CddlValue {
  FloatValue(value)
}

///|
pub fn text_value(value : String) -> CddlValue {
  TextValue(value)
}

///|
pub fn bytes_value(value : Bytes) -> CddlValue {
  BytesValue(value)
}

///|
pub fn array_value(value : Array[CddlValue]) -> CddlValue {
  ArrayValue(value.copy())
}

///|
pub fn map_value(value : Array[(CddlValue, CddlValue)]) -> CddlValue {
  MapValue(value.copy())
}

///|
pub fn tagged_value(tag : Int64, value : CddlValue) -> CddlValue {
  TaggedValue(tag, value)
}

///|
pub fn CddlValue::kind_name(self : CddlValue) -> String {
  match self {
    NullValue => "null"
    BoolValue(_) => "bool"
    IntegerValue(value) => if value >= 0L { "uint" } else { "nint" }
    FloatValue(_) => "float"
    TextValue(_) => "text"
    BytesValue(_) => "bytes"
    ArrayValue(_) => "array"
    MapValue(_) => "map"
    TaggedValue(_, _) => "tag"
  }
}

///|
pub fn CddlValue::array_items(self : CddlValue) -> Array[CddlValue]? {
  match self {
    ArrayValue(items) => Some(items.copy())
    _ => None
  }
}

///|
pub fn CddlValue::map_entries(
  self : CddlValue,
) -> Array[(CddlValue, CddlValue)]? {
  match self {
    MapValue(entries) => Some(entries.copy())
    _ => None
  }
}

///|
pub fn CddlValue::lookup_text(self : CddlValue, key : String) -> CddlValue? {
  match self {
    MapValue(entries) => {
      for entry in entries {
        if entry.0 == TextValue(key) {
          return Some(entry.1)
        }
      }
      None
    }
    _ => None
  }
}

///|
pub fn CddlValue::size(self : CddlValue) -> Int? {
  match self {
    TextValue(value) => Some(@utf8.encode(value[:]).length())
    BytesValue(value) => Some(value.length())
    ArrayValue(value) => Some(value.length())
    MapValue(value) => Some(value.length())
    _ => None
  }
}

///|
/// Compact diagnostic representation that never serializes complete
/// containers or byte payloads into error messages.
pub fn CddlValue::describe(self : CddlValue) -> String {
  match self {
    NullValue => "null"
    BoolValue(value) => value.to_string()
    IntegerValue(value) => value.to_string()
    FloatValue(value) => value.to_string()
    TextValue(value) => "\"" + value + "\""
    BytesValue(value) => "bstr(" + value.length().to_string() + " bytes)"
    ArrayValue(value) => "array(" + value.length().to_string() + " items)"
    MapValue(value) => "map(" + value.length().to_string() + " entries)"
    TaggedValue(tag, _) => "tag(" + tag.to_string() + ")"
  }
}
