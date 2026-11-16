///|
/// Names and tag assignments from RFC 8610 Appendix D; represented directly
/// rather than copying a reference implementation or textual prelude.
fn prelude_expression(name : String) -> TypeExpr? {
  let tag : Int64? = match name {
    "tdate" => Some(0L)
    "time" => Some(1L)
    "biguint" => Some(2L)
    "bignint" => Some(3L)
    "decfrac" => Some(4L)
    "bigfloat" => Some(5L)
    "eb64url" => Some(21L)
    "eb64legacy" => Some(22L)
    "eb16" => Some(23L)
    "encoded-cbor" => Some(24L)
    "uri" => Some(32L)
    "b64url" => Some(33L)
    "b64legacy" => Some(34L)
    "regexp" => Some(35L)
    "mime-message" => Some(36L)
    "cbor-any" => Some(55799L)
    _ => None
  }
  if tag is Some(number) {
    let body = match name {
      "tdate" | "uri" | "b64url" | "b64legacy" | "regexp" | "mime-message" =>
        Primitive(TextType)
      "time" => Primitive(NumberType)
      "biguint" | "bignint" | "encoded-cbor" => Primitive(BytesType)
      "decfrac" | "bigfloat" =>
        ArraySchema([
          group_entry(Primitive(IntType)),
          group_entry(Reference("integer")),
        ])
      _ => Primitive(AnyType)
    }
    return Some(TaggedSchema(number, body))
  }
  match name {
    "bigint" => Some(Choice([Reference("biguint"), Reference("bignint")]))
    "integer" => Some(Choice([Primitive(IntType), Reference("bigint")]))
    "unsigned" => Some(Choice([Primitive(UintType), Reference("biguint")]))
    "float16" => Some(MajorSchema(7, Some(25UL)))
    "float32" => Some(MajorSchema(7, Some(26UL)))
    "float64" => Some(MajorSchema(7, Some(27UL)))
    "float16-32" => Some(Choice([Reference("float16"), Reference("float32")]))
    "float32-64" => Some(Choice([Reference("float32"), Reference("float64")]))
    "true" => Some(Literal(BoolValue(true)))
    "false" => Some(Literal(BoolValue(false)))
    "undefined" => Some(Literal(SimpleValue(23)))
    _ => primitive_from_name(name).map(kind => Primitive(kind))
  }
}
