///|
fn repeated_text(length : Int) -> String {
  let output : Array[String] = []
  for _index = 0; _index < length; _index = _index + 1 {
    output.push("x")
  }
  output.join("")
}

///|
fn requested_size(expression : TypeExpr) -> Int? {
  match expression {
    Literal(IntegerValue(value)) if value >= 0L && value <= 2147483647L =>
      Some(value.to_int())
    IntegerRange(lower, _, _) if lower >= 0L && lower <= 2147483647L =>
      Some(lower.to_int())
    _ => None
  }
}

///|
fn sized_witness(target : TypeExpr, size : Int) -> CddlValue? {
  match target {
    Primitive(TextType) => Some(text_value(repeated_text(size)))
    Primitive(BytesType) =>
      Some(bytes_value(Bytes::from_array(Array::make(size, (0x00 : Byte))[:])))
    Primitive(ArrayTypeName) =>
      Some(array_value(Array::make(size, null_value())))
    Primitive(MapTypeName) => {
      let entries : Array[(CddlValue, CddlValue)] = []
      for index = 0; index < size; index = index + 1 {
        entries.push((text_value("key" + index.to_string()), null_value()))
      }
      Some(map_value(entries))
    }
    _ => None
  }
}

///|
fn numeric_control_witness(
  operator : ControlOperator,
  argument : TypeExpr,
) -> CddlValue? {
  match argument {
    Literal(IntegerValue(bound)) =>
      match operator {
        LessThanControl => Some(integer_value(bound - 1L))
        LessOrEqualControl => Some(integer_value(bound))
        GreaterThanControl => Some(integer_value(bound + 1L))
        GreaterOrEqualControl => Some(integer_value(bound))
        _ => None
      }
    Literal(FloatValue(bound)) =>
      match operator {
        LessThanControl => Some(float_value(bound - 1.0))
        LessOrEqualControl => Some(float_value(bound))
        GreaterThanControl => Some(float_value(bound + 1.0))
        GreaterOrEqualControl => Some(float_value(bound))
        _ => None
      }
    _ => None
  }
}

///|
fn generate_expression(
  document : Schema,
  expression : TypeExpr,
  limits : CddlLimits,
  stack : Array[String],
  depth : Int,
) -> Result[CddlValue, CddlError] {
  if depth > limits.max_depth() {
    return Err(
      cddl_error(ResourceLimit, "example generation exceeds max_depth"),
    )
  }
  match expression {
    Primitive(kind) =>
      Ok(
        match kind {
          AnyType | NilType => null_value()
          BoolType => bool_value(false)
          UintType | IntType | NumberType => integer_value(0L)
          NintType => integer_value(-1L)
          FloatType => float_value(0.0)
          TextType => text_value("")
          BytesType => bytes_value(Bytes::from_array([]))
          ArrayTypeName => array_value([])
          MapTypeName => map_value([])
        },
      )
    Literal(value) => Ok(value)
    Reference(name) => {
      if stack.contains(name) {
        return Err(
          cddl_error(
            RecursiveReference,
            "required recursive reference cannot produce a finite example: " +
            name,
          ),
        )
      }
      let target = match document.lookup(name) {
        Some(value) => value
        None => return Err(cddl_error(UnknownRule, "unknown rule: " + name))
      }
      let next_stack = stack.copy()
      next_stack.push(name)
      generate_expression(document, target, limits, next_stack, depth + 1)
    }
    Choice(alternatives) => {
      for alternative in alternatives {
        match
          generate_expression(document, alternative, limits, stack, depth + 1) {
          Ok(value) => return Ok(value)
          Err(_) => ()
        }
      }
      Err(
        cddl_error(
          ValidationFailure,
          "no choice alternative can generate an example",
        ),
      )
    }
    IntegerRange(lower, _, _) => Ok(integer_value(lower))
    ArraySchema(entries) => {
      let output : Array[CddlValue] = []
      for entry in entries {
        for _index = 0; _index < entry.occurrence().min(); _index = _index + 1 {
          match
            generate_expression(
              document,
              entry.value(),
              limits,
              stack,
              depth + 1,
            ) {
            Ok(value) => output.push(value)
            Err(error) => return Err(error)
          }
        }
      }
      Ok(array_value(output))
    }
    MapSchema(declarations) => {
      let output : Array[(CddlValue, CddlValue)] = []
      for declaration in declarations {
        let key_expression = match declaration.key() {
          Some(value) => value
          None => primitive(TextType)
        }
        for index = 0; index < declaration.occurrence().min(); index = index + 1 {
          let key = match
            generate_expression(
              document,
              key_expression,
              limits,
              stack,
              depth + 1,
            ) {
            Ok(TextValue("")) => text_value("key" + index.to_string())
            Ok(value) => value
            Err(error) => return Err(error)
          }
          let value = match
            generate_expression(
              document,
              declaration.value(),
              limits,
              stack,
              depth + 1,
            ) {
            Ok(value) => value
            Err(error) => return Err(error)
          }
          output.push((key, value))
        }
      }
      Ok(map_value(output))
    }
    TaggedSchema(tag, target) =>
      match generate_expression(document, target, limits, stack, depth + 1) {
        Ok(value) => Ok(tagged_value(tag, value))
        Err(error) => Err(error)
      }
    Controlled(target, operator, argument) =>
      match operator {
        EqualControl =>
          match argument {
            Literal(value) => Ok(value)
            _ =>
              Err(
                cddl_error(
                  ValidationFailure,
                  ".eq example requires a literal argument",
                ),
              )
          }
        NotEqualControl => {
          let candidate = match
            generate_expression(document, target, limits, stack, depth + 1) {
            Ok(value) => value
            Err(error) => return Err(error)
          }
          match argument {
            Literal(expected) if candidate == expected =>
              match candidate {
                IntegerValue(value) => Ok(integer_value(value + 1L))
                BoolValue(value) => Ok(bool_value(!value))
                TextValue(value) => Ok(text_value(value + "x"))
                _ =>
                  Err(
                    cddl_error(
                      ValidationFailure,
                      "cannot construct a distinct .ne value",
                    ),
                  )
              }
            _ => Ok(candidate)
          }
        }
        SizeControl =>
          match requested_size(argument) {
            Some(size) =>
              match sized_witness(target, size) {
                Some(value) => Ok(value)
                None =>
                  Err(
                    cddl_error(
                      ValidationFailure,
                      "example generator supports .size on direct text, bytes, array, and map types",
                    ),
                  )
              }
            None =>
              Err(
                cddl_error(
                  ValidationFailure,
                  ".size requires a non-negative size",
                ),
              )
          }
        LessThanControl
        | LessOrEqualControl
        | GreaterThanControl
        | GreaterOrEqualControl =>
          match numeric_control_witness(operator, argument) {
            Some(value) => Ok(value)
            None =>
              Err(
                cddl_error(
                  ValidationFailure,
                  "numeric control requires a literal bound",
                ),
              )
          }
        AndControl | WithinControl =>
          generate_expression(document, argument, limits, stack, depth + 1)
      }
  }
}

///|
/// Generate a deterministic minimal witness and validate it before returning.
/// Failure is explicit for uninhabitable required recursion or unsupported
/// generation shapes; the function never returns an unchecked fixture.
pub fn generate_example(
  document : Schema,
  root? : String? = None,
  limits? : CddlLimits = cddl_limits(),
) -> Result[CddlValue, CddlError] {
  let root_name = match root {
    Some(name) => name
    None =>
      match document.root_name() {
        Some(name) => name
        None => return Err(cddl_error(UnknownRule, "schema has no root rule"))
      }
  }
  let target = match document.lookup(root_name) {
    Some(value) => value
    None =>
      return Err(
        cddl_error(UnknownRule, "unknown generation root: " + root_name),
      )
  }
  let value = match
    generate_expression(document, target, limits, [root_name], 0) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let report = match validate(document, value, root=Some(root_name), limits~) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if report.is_valid() {
    Ok(value)
  } else {
    Err(
      cddl_error(
        ValidationFailure,
        "generated value failed self-validation: " +
        report.issues()[0].message(),
      ),
    )
  }
}
