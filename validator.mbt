///|
/// Result of validating one value. Validation mismatches are data, while
/// malformed schemas are rejected earlier by `parse_cddl`.
pub struct ValidationReport {
  valid : Bool
  issues : Array[ValidationIssue]
  truncated : Bool
} derive(Debug, Eq)

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
      }
  }
}

///|
fn primitive_matches(kind : PrimitiveType, value : CddlValue) -> Bool {
  match (kind, value) {
    (AnyType, _) => true
    (BoolType, BoolValue(_)) => true
    (NilType, NullValue) => true
    (UintType, IntegerValue(number)) => number >= 0L
    (NintType, IntegerValue(number)) => number < 0L
    (IntType, IntegerValue(_)) => true
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
fn map_entry_path(parent : String, key : CddlValue, index : Int) -> String {
  match key {
    TextValue(value) => parent + "/" + escaped_path_segment(value)
    IntegerValue(value) => parent + "/" + value.to_string()
    _ => parent + "/@" + index.to_string()
  }
}

///|
fn occurrence_max_reached(cardinality : Occurrence, count : Int) -> Bool {
  match cardinality.max() {
    Some(value) => count >= value
    None => false
  }
}

///|
fn try_validate(
  schema : Schema,
  limits : CddlLimits,
  expression : TypeExpr,
  value : CddlValue,
  path : String,
  depth : Int,
) -> Bool {
  let trial : ValidationContext = {
    schema,
    limits,
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
  depth : Int,
) -> Bool {
  for alternative in alternatives {
    if try_validate(
        context.schema,
        context.limits,
        alternative,
        value,
        path,
        depth + 1,
      ) {
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
  depth : Int,
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
          context.schema,
          context.limits,
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
  depth : Int,
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
      if try_validate(
          context.schema,
          context.limits,
          key_schema,
          entry.0,
          path,
          depth + 1,
        ) {
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
fn comparison_number(value : CddlValue) -> Double? {
  match value {
    IntegerValue(number) => Some(number.to_double())
    FloatValue(number) => Some(number)
    _ => None
  }
}

///|
fn validate_control(
  context : ValidationContext,
  target : TypeExpr,
  operator : ControlOperator,
  argument : TypeExpr,
  value : CddlValue,
  path : String,
  depth : Int,
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
    AndControl | WithinControl =>
      validate_expression(context, argument, value, path, depth + 1)
    SizeControl => {
      let actual_size = value.size()
      let size_value = match actual_size {
        Some(number) => IntegerValue(number.to_int64())
        None =>
          return report_mismatch(
            context,
            SizeMismatch,
            path,
            "sized value",
            value,
            ".size applies only to text, bytes, arrays, and maps",
          )
      }
      if try_validate(
          context.schema,
          context.limits,
          argument,
          size_value,
          path,
          depth + 1,
        ) {
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
    EqualControl | NotEqualControl => {
      let equal = match argument {
        Literal(expected) => value == expected
        _ => false
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
      let actual = comparison_number(value)
      let expected = match argument {
        Literal(literal_value) => comparison_number(literal_value)
        _ => None
      }
      match (actual, expected) {
        (Some(left), Some(right)) => {
          let valid = match operator {
            LessThanControl => left < right
            LessOrEqualControl => left <= right
            GreaterThanControl => left > right
            GreaterOrEqualControl => left >= right
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
  }
}

///|
fn validate_expression(
  context : ValidationContext,
  expression : TypeExpr,
  value : CddlValue,
  path : String,
  depth : Int,
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
    Primitive(kind) =>
      if primitive_matches(kind, value) {
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
      if value == expected {
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
          validate_array_group(context, entries, items, path, depth + 1)
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
          validate_map_group(context, declarations, entries, path, depth + 1)
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
  root? : String? = None,
  limits? : CddlLimits = cddl_limits(),
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
  }
  let valid = validate_expression(context, expression, value, "", 0)
  Ok({ valid, issues: context.issues, truncated: context.truncated })
}
