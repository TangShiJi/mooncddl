///|
fn singleton_value(
  document : Schema,
  expression : TypeExpr,
  depth : Int32,
) -> CddlValue? {
  if depth > 128 {
    return None
  }
  match resolve_head(document, expression, depth + 1) {
    Some(Literal(value)) => Some(value)
    Some(MajorSchema(0, Some(n))) => Some(exact_uint(n))
    Some(MajorSchema(1, Some(n))) => Some(exact_negative(n))
    Some(TaggedSchema(tag, body)) =>
      singleton_value(document, body, depth + 1).map(value => {
        TaggedValue(tag, value)
      })
    Some(ArraySchema(entries)) => {
      let values : Array[CddlValue] = []
      for entry in entries {
        if entry.occurrence() != once() {
          return None
        }
        match singleton_value(document, entry.value(), depth + 1) {
          Some(value) => values.push(value)
          None => return None
        }
      }
      Some(ArrayValue(values))
    }
    Some(MapSchema(entries)) => {
      let values : Array[(CddlValue, CddlValue)] = []
      for entry in entries {
        if entry.occurrence() != once() {
          return None
        }
        let key = match entry.key() {
          Some(key) => singleton_value(document, key, depth + 1)
          None => return None
        }
        match (key, singleton_value(document, entry.value(), depth + 1)) {
          (Some(key), Some(value)) => values.push((key, value))
          _ => return None
        }
      }
      Some(MapValue(values))
    }
    Some(Choice(items)) => {
      let mut only : CddlValue? = None
      for item in items {
        match singleton_value(document, item, depth + 1) {
          Some(value) => {
            if only is Some(previous) && !data_equal(previous, value, false) {
              return None
            }
            only = Some(value)
          }
          None => return None
        }
      }
      only
    }
    _ => None
  }
}
