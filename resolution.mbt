///|
fn as_group(value : TypeExpr) -> Array[GroupEntry] {
  [group_entry(value)]
}

///|
fn substitute(
  expression : TypeExpr,
  parameters : Array[String],
  arguments : Array[TypeExpr],
) -> TypeExpr {
  match expression {
    Reference(name) => {
      for index, parameter in parameters {
        if parameter == name && index < arguments.length() {
          return arguments[index]
        }
      }
      expression
    }
    Choice(items) =>
      Choice(items.map(item => substitute(item, parameters, arguments)))
    Application(name, args) =>
      Application(
        name,
        args.map(item => substitute(item, parameters, arguments)),
      )
    ArraySchema(entries) =>
      ArraySchema(substitute_entries(entries, parameters, arguments))
    MapSchema(entries) =>
      MapSchema(substitute_entries(entries, parameters, arguments))
    GroupSchema(alternatives) =>
      GroupSchema(
        alternatives.map(entries => {
          substitute_entries(entries, parameters, arguments)
        }),
      )
    TaggedSchema(tag, body) =>
      TaggedSchema(tag, substitute(body, parameters, arguments))
    Controlled(target, op, controller) =>
      Controlled(
        substitute(target, parameters, arguments),
        op,
        substitute(controller, parameters, arguments),
      )
    DynamicRange(lower, upper, exclusive) =>
      DynamicRange(
        substitute(lower, parameters, arguments),
        substitute(upper, parameters, arguments),
        exclusive,
      )
    Unwrap(body) => Unwrap(substitute(body, parameters, arguments))
    Enumeration(body) => Enumeration(substitute(body, parameters, arguments))
    _ => expression
  }
}

///|
fn substitute_entries(
  entries : Array[GroupEntry],
  parameters : Array[String],
  arguments : Array[TypeExpr],
) -> Array[GroupEntry] {
  entries.map(entry => {
    group_entry(
      substitute(entry.value(), parameters, arguments),
      key=entry.key().map(key => substitute(key, parameters, arguments)),
      occurrence=entry.occurrence(),
      cut=entry.is_cut(),
    )
  })
}

///|
fn resolve_head(
  document : Schema,
  expression : TypeExpr,
  depth : Int32,
) -> TypeExpr? {
  if depth > 128 {
    return None
  }
  match expression {
    Reference(name) =>
      match document.lookup(name) {
        Some(value) => resolve_head(document, value, depth + 1)
        None => None
      }
    Application(name, arguments) => {
      for item in document.rules() {
        if item.name() == name &&
          item.parameters().length() == arguments.length() {
          return resolve_head(
            document,
            substitute(item.value(), item.parameters(), arguments),
            depth + 1,
          )
        }
      }
      None
    }
    Unwrap(body) =>
      match resolve_head(document, body, depth + 1) {
        Some(ArraySchema(entries)) | Some(MapSchema(entries)) =>
          Some(GroupSchema([entries]))
        Some(TaggedSchema(_, value)) => resolve_head(document, value, depth + 1)
        _ => None
      }
    _ => Some(expression)
  }
}

///|
fn enumeration_members(
  document : Schema,
  expression : TypeExpr,
  depth : Int32,
) -> Array[TypeExpr] {
  if depth > 128 {
    return []
  }
  match resolve_head(document, expression, depth + 1) {
    Some(GroupSchema(alternatives)) => {
      let result : Array[TypeExpr] = []
      for entries in alternatives {
        for entry in entries {
          let value = entry.value()
          match resolve_head(document, value, depth + 1) {
            Some(GroupSchema(_)) =>
              result.append(enumeration_members(document, value, depth + 1))
            _ => result.push(value)
          }
        }
      }
      result
    }
    Some(value) => [value]
    None => []
  }
}
