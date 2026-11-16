///|
priv suberror EmbeddedCborError {
  EmbeddedCborError(String)
}

///|
priv struct CborReader {
  bytes : Bytes
  limits : CddlLimits
  mut offset : Int32
}

///|
fn CborReader::byte(self : CborReader) -> Int32 raise EmbeddedCborError {
  if self.offset >= self.bytes.length() {
    raise EmbeddedCborError("truncated CBOR")
  }
  let byte = self.bytes[self.offset].to_int()
  self.offset += 1
  byte
}

///|
fn CborReader::argument(
  self : CborReader,
  ai : Int32,
) -> UInt64 raise EmbeddedCborError {
  if ai < 24 {
    return ai.to_uint64()
  }
  let count = match ai {
    24 => 1
    25 => 2
    26 => 4
    27 => 8
    _ => raise EmbeddedCborError("reserved or indefinite argument")
  }
  let mut value = 0UL
  for _i = 0; _i < count; _i = _i + 1 {
    value = (value << 8) | self.byte().to_uint64()
  }
  value
}

///|
fn CborReader::payload(
  self : CborReader,
  length : UInt64,
) -> Bytes raise EmbeddedCborError {
  if length > (self.bytes.length() - self.offset).to_uint64() {
    raise EmbeddedCborError("truncated CBOR string")
  }
  let count = length.to_int()
  let bytes = self.bytes[self.offset:self.offset + count].to_owned()
  self.offset += count
  bytes
}

///|
fn CborReader::text(
  _self : CborReader,
  bytes : Bytes,
) -> String raise EmbeddedCborError {
  @utf8.decode(bytes[:], ignore_bom=false) catch {
    _ => raise EmbeddedCborError("invalid UTF-8 in CBOR text")
  }
}

///|
fn CborReader::string(
  self : CborReader,
  major : Int32,
  ai : Int32,
) -> CddlValue raise EmbeddedCborError {
  let output : Array[Byte] = []
  if ai != 31 {
    let bytes = self.payload(self.argument(ai))
    return if major == 2 {
      BytesValue(bytes)
    } else {
      TextValue(self.text(bytes))
    }
  }
  while true {
    let head = self.byte()
    if head == 255 {
      break
    }
    if head >> 5 != major || (head & 31) == 31 {
      raise EmbeddedCborError("invalid indefinite string chunk")
    }
    let chunk = self.payload(self.argument(head & 31))
    // Every text chunk must independently contain complete UTF-8 scalars.
    if major == 3 {
      ignore(self.text(chunk))
    }
    for byte in chunk {
      output.push(byte)
    }
  }
  let bytes = Bytes::from_array(output[:])
  if major == 2 {
    BytesValue(bytes)
  } else {
    TextValue(self.text(bytes))
  }
}

///|
fn decode_half(bits : UInt64) -> Double {
  let sign = if (bits & 32768UL) != 0UL { -1.0 } else { 1.0 }
  let exponent = ((bits >> 10) & 31UL).to_int()
  let fraction = (bits & 1023UL).to_double()
  if exponent == 0 {
    sign * fraction / 16777216.0
  } else if exponent == 31 {
    if fraction == 0.0 {
      sign / 0.0
    } else {
      0.0 / 0.0
    }
  } else {
    sign *
    (1.0 + fraction / 1024.0) *
    @math.pow(2.0, (exponent - 15).to_double())
  }
}

///|
fn CborReader::value(
  self : CborReader,
  depth : Int32,
) -> CddlValue raise EmbeddedCborError {
  if depth > self.limits.max_depth() {
    raise EmbeddedCborError("CBOR max_depth exceeded")
  }
  let head = self.byte()
  let major = head >> 5
  let ai = head & 31
  if major == 2 || major == 3 {
    return self.string(major, ai)
  }
  if major == 4 || major == 5 {
    let count = if ai == 31 { None } else { Some(self.argument(ai)) }
    if count is Some(n) && n > self.limits.max_container_items().to_uint64() {
      raise EmbeddedCborError("CBOR container limit exceeded")
    }
    let array : Array[CddlValue] = []
    let map : Array[(CddlValue, CddlValue)] = []
    let mut index = 0
    while true {
      if count == Some(index.to_uint64()) {
        break
      }
      if count is None &&
        self.offset < self.bytes.length() &&
        self.bytes[self.offset] == 255 {
        self.offset += 1
        break
      }
      if index >= self.limits.max_container_items() {
        raise EmbeddedCborError("CBOR container limit exceeded")
      }
      let first = self.value(depth + 1)
      if major == 4 {
        array.push(first)
      } else {
        let second = self.value(depth + 1)
        if map.any(entry => data_equal(entry.0, first, false)) {
          raise EmbeddedCborError("duplicate CBOR map key")
        }
        map.push((first, second))
      }
      index += 1
    }
    return if major == 4 { ArrayValue(array) } else { MapValue(map) }
  }
  let argument = self.argument(ai)
  match major {
    0 => exact_uint(argument)
    1 => exact_negative(argument)
    6 => {
      let body = self.value(depth + 1)
      if argument <= 9223372036854775807UL {
        TaggedValue(argument.reinterpret_as_int64(), body)
      } else {
        WideTagValue(argument, body)
      }
    }
    7 =>
      match ai {
        20 => BoolValue(false)
        21 => BoolValue(true)
        22 => NullValue
        25 => FloatValue(decode_half(argument))
        26 =>
          FloatValue(
            Float::reinterpret_from_uint(argument.to_uint()).to_double(),
          )
        27 => FloatValue(argument.reinterpret_as_double())
        24 if argument < 32UL =>
          raise EmbeddedCborError("non-well-formed simple value")
        _ => SimpleValue(argument.to_int())
      }
    _ => raise EmbeddedCborError("invalid CBOR major type")
  }
}

///|
/// Decode exactly one well-formed CBOR item for .cbor validation. This API
/// preserves the complete CBOR integer domain and rejects trailing bytes.
pub fn decode_cbor(
  bytes : Bytes,
  limits~ : CddlLimits = cddl_limits(),
) -> Result[CddlValue, CddlError] {
  decode_embedded(bytes, false, limits)
}

///|
/// Decode a CBOR sequence into the array model required by RFC 8610 .cborseq.
pub fn decode_cbor_sequence(
  bytes : Bytes,
  limits~ : CddlLimits = cddl_limits(),
) -> Result[CddlValue, CddlError] {
  decode_embedded(bytes, true, limits)
}

///|
fn decode_embedded(
  bytes : Bytes,
  sequence : Bool,
  limits : CddlLimits,
) -> Result[CddlValue, CddlError] {
  if bytes.length() > limits.max_source_bytes() {
    return Err(cddl_error(ResourceLimit, "CBOR max_source_bytes exceeded"))
  }
  let reader : CborReader = { bytes, limits, offset: 0, }
  try {
    if sequence {
      let items : Array[CddlValue] = []
      while reader.offset < bytes.length() {
        if items.length() >= limits.max_container_items() {
          raise EmbeddedCborError("CBOR sequence limit exceeded")
        }
        items.push(reader.value(0))
      }
      Ok(ArrayValue(items))
    } else {
      let value = reader.value(0)
      if reader.offset != bytes.length() {
        raise EmbeddedCborError("trailing bytes after CBOR item")
      }
      Ok(value)
    }
  } catch {
    EmbeddedCborError(message) => Err(cddl_error(ValidationFailure, message))
  }
}
