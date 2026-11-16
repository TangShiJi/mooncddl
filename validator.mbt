///|
/// Result of validating one value. Validation mismatches are data, while
/// malformed schemas are rejected earlier by `parse_cddl`.
#derive(Debug, Eq)
pub struct ValidationReport {
  valid : Bool
  issues : Array[ValidationIssue]
  truncated : Bool
}

///|
pub fn ValidationReport::is_valid(self : ValidationReport) -> Bool {
  self.valid
}

///|
pub fn ValidationReport::issues(
  self : ValidationReport,
) -> Array[ValidationIssue] {
  self.issues.copy()
}

///|
pub fn ValidationReport::truncated(self : ValidationReport) -> Bool {
  self.truncated
}

///|
priv struct ValidationContext {
  schema : Schema
  limits : CddlLimits
  issues : Array[ValidationIssue]
  mut truncated : Bool
  json_mode : Bool
}

///|
fn ValidationContext::add_issue(
  self : ValidationContext,
  issue : ValidationIssue,
) -> Unit {
  if self.issues.length() < self.limits.max_issues() {
    self.issues.push(issue)
  } else {
    self.truncated = true
  }
}

///|
fn expression_name(expression : TypeExpr) -> String {
  match expression {
    Primitive(kind) =>
      match kind {
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
    Literal(value) => "literal " + value.describe()
    Reference(name) => name
    MajorSchema(major, _) => "CBOR major type " + major.to_string()
    ValueRange(_, _, _) => "numeric range"
    DynamicRange(_, _, _) => "named numeric range"
    Application(name, _) => name + "<...>"
    Unwrap(_) => "unwrapped group"
    Enumeration(_) => "group enumeration"
    GroupSchema(_) => "group choice"
    Choice(_) => "choice"
    IntegerRange(lower, upper, exclusive) =>
      lower.to_string() +
      (if exclusive { "..." } else { ".." }) +
      upper.to_string()
    ArraySchema(_) => "array group"
    MapSchema(_) => "map group"
    TaggedSchema(tag, _) => "CBOR tag " + tag.to_string()
    Controlled(_, operator, _) =>
      match operator {
        SizeControl => ".size constraint"
        LessThanControl => ".lt constraint"
        LessOrEqualControl => ".le constraint"
        GreaterThanControl => ".gt constraint"
        GreaterOrEqualControl => ".ge constraint"
        EqualControl => ".eq constraint"
        NotEqualControl => ".ne constraint"
        AndControl => ".and constraint"
        WithinControl => ".within constraint"
        BitsControl => ".bits constraint"
        DefaultControl => ".default annotation"
        TagContentControl => "tag content"
        CborControl => "embedded CBOR"
        CborSequenceControl => "embedded CBOR sequence"
        RegexpControl => "XSD regular expression"
      }
  }
}

///|
fn primitive_matches(
  kind : PrimitiveType,
  value : CddlValue,
  json_mode : Bool,
) -> Bool {
  if json_mode && value is FloatValue(n) && n == n.floor() {
    match kind {
      UintType => return n >= 0.0 && n < 18446744073709551616.0
      NintType => return n < 0.0 && n >= -18446744073709551616.0
      IntType =>
        return n >= -18446744073709551616.0 && n < 18446744073709551616.0
      _ => ()
    }
  }
  if json_mode && kind == FloatType && numeric_double(value) is Some(n) {
    return compare_number(value, FloatValue(n)) == Some(0)
  }
  match (kind, value) {
    (AnyType, _) => true
    (BoolType, BoolValue(_)) => true
    (NilType, NullValue) => true
    (UintType, IntegerValue(number)) => number >= 0L
    (NintType, IntegerValue(number)) => number < 0L
    (IntType, IntegerValue(_)) => true
    (UintType | IntType | NumberType, UnsignedValue(_)) => true
    (NintType | IntType | NumberType, NegativeValue(_)) => true
    (FloatType | NumberType, EncodedFloat(_, _)) => true
    (FloatType, FloatValue(_)) => true
    (NumberType, IntegerValue(_) | FloatValue(_)) => true
    (TextType, TextValue(_)) => true
    (BytesType, BytesValue(_)) => true
    (ArrayTypeName, ArrayValue(_)) => true
    (MapTypeName, MapValue(_)) => true
    _ => false
  }
}

///|
fn escaped_path_segment(value : String) -> String {
  value.replace(old="~", new="~0").replace(old="/", new="~1")
}

///|
fn map_entry_path(parent : String, key : CddlValue, index : Int32) -> String {
  match key {
    TextValue(value) => parent + "/" + escaped_path_segment(value)
    IntegerValue(value) => parent + "/" + value.to_string()
    _ => parent + "/@" + index.to_string()
  }
}

///|
fn occurrence_max_reached(cardinality : Occurrence, count : Int32) -> Bool {
  match cardinality.max() {
    Some(value) => count >= value
    None => false
  }
}

///|
fn try_validate(
  context : ValidationContext,
  expression : TypeExpr,
  value : CddlValue,
  path : String,
  depth : Int32,
) -> Bool {
  let trial : ValidationContext = {
    schema: context.schema,
    limits: context.limits,
    json_mode: context.json_mode,
    issues: [],
    truncated: false,
  }
  validate_expression(trial, expression, value, path, depth)
}

///|
fn report_mismatch(
  context : ValidationContext,
  code : IssueCode,
  path : String,
  expected : String,
  value : CddlValue,
  message : String,
) -> Bool {
  context.add_issue(
    validation_issue(code, path, expected, value.kind_name(), message),
  )
  false
}

///|
fn validate_choice(
  context : ValidationContext,
  alternatives : Array[TypeExpr],
  value : CddlValue,
  path : String,
  depth : Int32,
) -> Bool {
  for alternative in alternatives {
    if try_validate(context, alternative, value, path, depth + 1) {
      return true
    }
  }
  report_mismatch(
    context,
    TypeMismatch,
    path,
    "one of " + alternatives.length().to_string() + " alternatives",
    value,
    "value does not match any choice alternative",
  )
}

///|
fn validate_array_group(
  context : ValidationContext,
  entries : Array[GroupEntry],
  items : Array[CddlValue],
  path : String,
  depth : Int32,
) -> Bool {
  if items.length() > context.limits.max_container_items() {
    return report_mismatch(
      context,
      TooManyItems,
      path,
      "at most " + context.limits.max_container_items().to_string() + " items",
      ArrayValue(items),
      "array exceeds max_container_items",
    )
  }
  let mut item_index = 0
  let mut valid = true
  for entry in entries {
    let cardinality = entry.occurrence()
    let mut count = 0
    while item_index < items.length() &&
          !occurrence_max_reached(cardinality, count) {
      let item_path = path + "/" + item_index.to_string()
      if try_validate(
          context,
          entry.value(),
          items[item_index],
          item_path,
          depth + 1,
        ) {
        count += 1
        item_index += 1
      } else {
        break
      }
    }
    if count < cardinality.min() {
      valid = false
      let issue_path = path + "/" + item_index.to_string()
      context.add_issue(
        validation_issue(
          TooFewItems,
          issue_path,
          expression_name(entry.value()),
          if item_index < items.length() {
            items[item_index].kind_name()
          } else {
            "end of array"
          },
          "array group requires at least " +
          cardinality.min().to_string() +
          " matching item(s), found " +
          count.to_string(),
        ),
      )
    }
  }
  while item_index < items.length() {
    valid = false
    context.add_issue(
      validation_issue(
        UnexpectedMember,
        path + "/" + item_index.to_string(),
        "end of array",
        items[item_index].kind_name(),
        "array contains an unexpected item",
      ),
    )
    item_index += 1
  }
  valid
}

///|
fn validate_map_group(
  context : ValidationContext,
  declarations : Array[GroupEntry],
  entries : Array[(CddlValue, CddlValue)],
  path : String,
  depth : Int32,
) -> Bool {
  if entries.length() > context.limits.max_container_items() {
    return report_mismatch(
      context,
      TooManyItems,
      path,
      "at most " + context.limits.max_container_items().to_string() + " entries",
      MapValue(entries),
      "map exceeds max_container_items",
    )
  }
  let consumed = Array::make(entries.length(), false)
  let mut valid = true
  for declaration in declarations {
    let key_schema = match declaration.key() {
      Some(value) => value
      None => primitive(AnyType)
    }
    let cardinality = declaration.occurrence()
    let mut count = 0
    for index, entry in entries {
      if consumed[index] || occurrence_max_reached(cardinality, count) {
        continue
      }
      if try_validate(context, key_schema, entry.0, path, depth + 1) {
        let entry_path = map_entry_path(path, entry.0, index)
        consumed[index] = true
        count += 1
        if !validate_expression(
            context,
            declaration.value(),
            entry.1,
            entry_path,
            depth + 1,
          ) {
          valid = false
        }
      }
    }
    if count < cardinality.min() {
      valid = false
      context.add_issue(
        validation_issue(
          MissingMember,
          path,
          expression_name(key_schema),
          "missing",
          "map requires at least " +
          cardinality.min().to_string() +
          " matching member(s), found " +
          count.to_string(),
        ),
      )
    }
  }
  for index, entry in entries {
    if !consumed[index] {
      valid = false
      context.add_issue(
        validation_issue(
          UnexpectedMember,
          map_entry_path(path, entry.0, index),
          "declared map member",
          entry.1.kind_name(),
          "map contains an undeclared member",
        ),
      )
    }
  }
  valid
}

///|
fn validate_control(
  context : ValidationContext,
  target : TypeExpr,
  operator : ControlOperator,
  argument : TypeExpr,
  value : CddlValue,
  path : String,
  depth : Int32,
) -> Bool {
  let target_valid = validate_expression(
    context,
    target,
    value,
    path,
    depth + 1,
  )
  if !target_valid {
    return false
  }
  match operator {
    RegexpControl =>
      match (value, resolve_head(context.schema, argument, 0)) {
        (TextValue(text), Some(Literal(TextValue(pattern)))) =>
          match match_xsd_regex(pattern, text, limits=context.limits) {
            Ok(true) => true
            _ =>
              report_mismatch(
                context,
                ComparisonFailed,
                path,
                "XSD regular expression",
                value,
                "text does not match XSD pattern or pattern resource limit reached",
              )
          }
        _ =>
          report_mismatch(
            context,
            ComparisonFailed,
            path,
            "text and singleton text controller",
            value,
            ".regexp requires text",
          )
      }
    CborControl | CborSequenceControl =>
      match value {
        BytesValue(bytes) => {
          let decoded = if operator == CborControl {
            decode_cbor(bytes, limits=context.limits)
          } else {
            decode_cbor_sequence(bytes, limits=context.limits)
          }
          match decoded {
            Ok(decoded) =>
              validate_expression(context, argument, decoded, path, depth + 1)
            Err(_) =>
              report_mismatch(
                context,
                TypeMismatch,
                path,
                "well-formed embedded CBOR",
                value,
                "embedded CBOR is malformed or exceeds resource limits",
              )
          }
        }
        _ => false
      }
    TagContentControl =>
      match value {
        TaggedValue(_, body) | WideTagValue(_, body) =>
          validate_expression(context, argument, body, path, depth + 1)
        _ => false
      }
    AndControl | WithinControl =>
      validate_expression(context, argument, value, path, depth + 1)
    SizeControl => {
      if unsigned_component(value) is Some(number) {
        let mut width = 0
        let mut rest = number
        while rest > 0UL {
          width += 1
          rest = rest >> 8
        }
        let bound = capacity_upper_bound(context.schema, argument, 0)
        let mut capacity_allowed = bound is Some(n) && n >= width.to_uint64()
        for n = width; n <= 8; n = n + 1 {
          if try_validate(
              context,
              argument,
              IntegerValue(n.to_int64()),
              path,
              depth + 1,
            ) {
            capacity_allowed = true
            break
          }
        }
        if capacity_allowed {
          return true
        }
        return report_mismatch(
          context,
          SizeMismatch,
          path,
          "unsigned integer byte capacity",
          value,
          "uint does not fit .size controller",
        )
      }
      let actual_size = match value {
        TextValue(_) | BytesValue(_) => value.size()
        _ => None
      }
      let size_value = match actual_size {
        Some(number) => IntegerValue(number.to_int64())
        None =>
          return report_mismatch(
            context,
            SizeMismatch,
            path,
            "sized value",
            value,
            ".size applies only to unsigned integers, text, and bytes",
          )
      }
      if try_validate(context, argument, size_value, path, depth + 1) {
        true
      } else {
        report_mismatch(
          context,
          SizeMismatch,
          path,
          expression_name(argument),
          value,
          "value size does not satisfy .size",
        )
      }
    }
    EqualControl | NotEqualControl | DefaultControl => {
      let equal = match singleton_value(context.schema, argument, 0) {
        Some(expected) => data_equal(value, expected, true)
        None =>
          return report_mismatch(
            context,
            ComparisonFailed,
            path,
            "singleton controller",
            value,
            "equality controller must denote exactly one value",
          )
      }
      let valid = if operator == EqualControl { equal } else { !equal }
      if valid {
        true
      } else {
        report_mismatch(
          context,
          ComparisonFailed,
          path,
          expression_name(argument),
          value,
          "value does not satisfy equality control",
        )
      }
    }
    LessThanControl
    | LessOrEqualControl
    | GreaterThanControl
    | GreaterOrEqualControl => {
      let controller = match resolve_head(context.schema, argument, 0) {
        Some(Literal(value)) => Some(value)
        _ => None
      }
      match
        controller.map(bound => compare_number(value, bound)).unwrap_or(None) {
        Some(order) => {
          let valid = match operator {
            LessThanControl => order < 0
            LessOrEqualControl => order <= 0
            GreaterThanControl => order > 0
            GreaterOrEqualControl => order >= 0
            _ => false
          }
          if valid {
            true
          } else {
            report_mismatch(
              context,
              ComparisonFailed,
              path,
              expression_name(argument),
              value,
              "numeric comparison control failed",
            )
          }
        }
        _ =>
          report_mismatch(
            context,
            ComparisonFailed,
            path,
            "numeric control argument",
            value,
            "comparison controls require numeric values and literal arguments",
          )
      }
    }
    BitsControl => {
      let bytes = match value {
        BytesValue(bytes) => bytes
        _ if unsigned_component(value) is Some(number) => {
          let out : Array[Byte] = []
          let mut rest = number
          while rest > 0UL {
            out.push((rest & 255UL).to_int().to_byte())
            rest = rest >> 8
          }
          Bytes::from_array(out[:])
        }
        _ =>
          return report_mismatch(
            context,
            ComparisonFailed,
            path,
            "uint or bstr",
            value,
            ".bits requires unsigned integer or byte string",
          )
      }
      for index, byte in bytes {
        for bit = 0; bit < 8; bit = bit + 1 {
          if (byte.to_int() & (1 << bit)) != 0 &&
            !try_validate(
              context,
              argument,
              integer_value(index.to_int64() * 8L + bit.to_int64()),
              path,
              depth + 1,
            ) {
            return report_mismatch(
              context,
              ComparisonFailed,
              path,
              expression_name(argument),
              value,
              "a set bit is not permitted by .bits",
            )
          }
        }
      }
      true
    }
  }
}

///|
fn validate_expression(
  context : ValidationContext,
  expression : TypeExpr,
  value : CddlValue,
  path : String,
  depth : Int32,
) -> Bool {
  if depth > context.limits.max_depth() {
    return report_mismatch(
      context,
      RecursionLimit,
      path,
      "depth <= " + context.limits.max_depth().to_string(),
      value,
      "validation recursion exceeds max_depth",
    )
  }
  match expression {
    MajorSchema(major, argument) => {
      let adjusted = if context.json_mode &&
        major == 7 &&
        numeric_double(value) is Some(n) &&
        compare_number(value, FloatValue(n)) == Some(0) {
        FloatValue(n)
      } else if context.json_mode &&
        (major == 0 || major == 1) &&
        value is FloatValue(n) &&
        n == n.floor() {
        if n >= 0.0 && n < 18446744073709551616.0 {
          if n < 9223372036854775808.0 {
            IntegerValue(n.to_int64())
          } else {
            exact_uint(
              (n - 9223372036854775808.0).to_int64().reinterpret_as_uint64() +
              9223372036854775808UL,
            )
          }
        } else if n < 0.0 && n >= -18446744073709551616.0 {
          if n >= -9223372036854775808.0 {
            IntegerValue(n.to_int64())
          } else {
            exact_negative(
              (-n - 9223372036854775808.0).to_int64().reinterpret_as_uint64() +
              9223372036854775807UL,
            )
          }
        } else {
          value
        }
      } else {
        value
      }
      if major_matches(major, argument, adjusted) {
        true
      } else {
        report_mismatch(
          context,
          TypeMismatch,
          path,
          expression_name(expression),
          value,
          "CBOR major type or additional information mismatch",
        )
      }
    }
    ValueRange(lower, upper, exclusive) => {
      let float_bounds = lower is FloatValue(_) || lower is EncodedFloat(_, _)
      let float_value = value is FloatValue(_) || value is EncodedFloat(_, _)
      if !context.json_mode && float_bounds != float_value {
        return report_mismatch(
          context,
          TypeMismatch,
          path,
          "same numeric kind as range bounds",
          value,
          "integer and float ranges are distinct",
        )
      }
      if context.json_mode &&
        !float_bounds &&
        numeric_double(value) is Some(n) &&
        n != n.floor() {
        return report_mismatch(
          context,
          TypeMismatch,
          path,
          "integral JSON number",
          value,
          "integer range requires an integral value",
        )
      }
      let valid = match
        (compare_number(value, lower), compare_number(value, upper)) {
        (Some(a), Some(b)) => a >= 0 && (if exclusive { b < 0 } else { b <= 0 })
        _ => false
      }
      if valid {
        true
      } else {
        report_mismatch(
          context,
          OutOfRange,
          path,
          "numeric range",
          value,
          "numeric value is outside the declared range",
        )
      }
    }
    DynamicRange(lower, upper, exclusive) =>
      match
        (
          resolve_head(context.schema, lower, 0),
          resolve_head(context.schema, upper, 0),
        ) {
        (Some(Literal(a)), Some(Literal(b))) =>
          validate_expression(
            context,
            ValueRange(a, b, exclusive),
            value,
            path,
            depth + 1,
          )
        _ =>
          report_mismatch(
            context,
            OutOfRange,
            path,
            "singleton numeric range bounds",
            value,
            "range bounds do not resolve to numeric literals",
          )
      }
    Application(_, _) | Unwrap(_) =>
      match resolve_head(context.schema, expression, 0) {
        Some(target) =>
          validate_expression(context, target, value, path, depth + 1)
        None =>
          report_mismatch(
            context,
            UnknownReference,
            path,
            expression_name(expression),
            value,
            "generic arity, reference, or unwrap target is invalid",
          )
      }
    Enumeration(body) =>
      validate_choice(
        context,
        enumeration_members(context.schema, body, 0),
        value,
        path,
        depth + 1,
      )
    GroupSchema(_) =>
      report_mismatch(
        context,
        TypeMismatch,
        path,
        "group inside a container",
        value,
        "a group is not a standalone value type",
      )
    Primitive(kind) =>
      if primitive_matches(kind, value, context.json_mode) {
        true
      } else {
        report_mismatch(
          context,
          TypeMismatch,
          path,
          expression_name(expression),
          value,
          "value has the wrong CDDL data type",
        )
      }
    Literal(expected) =>
      if data_equal(value, expected, context.json_mode) {
        true
      } else {
        report_mismatch(
          context,
          LiteralMismatch,
          path,
          expected.describe(),
          value,
          "value does not equal the required literal",
        )
      }
    Reference(name) =>
      match context.schema.lookup(name) {
        Some(target) =>
          validate_expression(context, target, value, path, depth + 1)
        None =>
          report_mismatch(
            context,
            UnknownReference,
            path,
            name,
            value,
            "referenced rule is unavailable",
          )
      }
    Choice(alternatives) =>
      validate_choice(context, alternatives, value, path, depth + 1)
    IntegerRange(lower, upper, exclusive) =>
      match value {
        FloatValue(n) if context.json_mode && n == n.floor() => {
          let valid = compare_number(value, IntegerValue(lower)).unwrap_or(-1) >=
            0 &&
            (if exclusive {
              compare_number(value, IntegerValue(upper)).unwrap_or(1) < 0
            } else {
              compare_number(value, IntegerValue(upper)).unwrap_or(1) <= 0
            })
          if valid {
            true
          } else {
            report_mismatch(
              context,
              OutOfRange,
              path,
              "integer range",
              value,
              "JSON number is outside range",
            )
          }
        }
        IntegerValue(number) => {
          let within = number >= lower &&
            (if exclusive { number < upper } else { number <= upper })
          if within {
            true
          } else {
            report_mismatch(
              context,
              OutOfRange,
              path,
              expression_name(expression),
              value,
              "integer is outside the declared range",
            )
          }
        }
        _ =>
          report_mismatch(
            context,
            TypeMismatch,
            path,
            expression_name(expression),
            value,
            "integer range requires an integer value",
          )
      }
    ArraySchema(entries) =>
      match value {
        ArrayValue(items) =>
          match match_complete_group(context, entries, value, path, depth + 1) {
            Some(true) => true
            Some(false) => {
              ignore(
                validate_array_group(context, entries, items, path, depth + 1),
              )
              if context.issues.length() == 0 {
                ignore(
                  report_mismatch(
                    context,
                    TypeMismatch,
                    path,
                    "complete array group",
                    value,
                    "no complete group match",
                  ),
                )
              }
              false
            }
            None =>
              report_mismatch(
                context,
                RecursionLimit,
                path,
                "bounded group search",
                value,
                "group matching resource limit reached",
              )
          }
        _ =>
          report_mismatch(
            context,
            TypeMismatch,
            path,
            "array",
            value,
            "expected an array",
          )
      }
    MapSchema(declarations) =>
      match value {
        MapValue(entries) =>
          match
            match_complete_group(context, declarations, value, path, depth + 1) {
            Some(true) => true
            Some(false) => {
              ignore(
                validate_map_group(
                  context,
                  declarations,
                  entries,
                  path,
                  depth + 1,
                ),
              )
              if context.issues.length() == 0 {
                ignore(
                  report_mismatch(
                    context,
                    TypeMismatch,
                    path,
                    "complete map group",
                    value,
                    "no complete group match",
                  ),
                )
              }
              false
            }
            None =>
              report_mismatch(
                context,
                RecursionLimit,
                path,
                "bounded group search",
                value,
                "group matching resource limit reached",
              )
          }
        _ =>
          report_mismatch(
            context,
            TypeMismatch,
            path,
            "map",
            value,
            "expected a map",
          )
      }
    TaggedSchema(tag, target) =>
      match value {
        TaggedValue(actual_tag, nested) if actual_tag == tag =>
          validate_expression(
            context,
            target,
            nested,
            path + "/@value",
            depth + 1,
          )
        _ =>
          report_mismatch(
            context,
            TypeMismatch,
            path,
            "CBOR tag " + tag.to_string(),
            value,
            "value does not carry the required CBOR tag",
          )
      }
    Controlled(target, operator, argument) =>
      validate_control(
        context,
        target,
        operator,
        argument,
        value,
        path,
        depth + 1,
      )
  }
}

///|
/// Validate against a named rule. When omitted, the first rule is used.
pub fn validate(
  document : Schema,
  value : CddlValue,
  root~ : String? = None,
  limits~ : CddlLimits = cddl_limits(),
  json_mode~ : Bool = false,
) -> Result[ValidationReport, CddlError] {
  let root_name = match root {
    Some(name) => name
    None =>
      match document.root_name() {
        Some(name) => name
        None => return Err(cddl_error(UnknownRule, "schema has no root rule"))
      }
  }
  let expression = match document.lookup(root_name) {
    Some(value) => value
    None =>
      return Err(
        cddl_error(UnknownRule, "unknown validation root: " + root_name),
      )
  }
  let context : ValidationContext = {
    schema: document,
    limits,
    issues: [],
    truncated: false,
    json_mode,
  }
  let valid = validate_expression(context, expression, value, "", 0)
  Ok({ valid, issues: context.issues, truncated: context.truncated, })
}
