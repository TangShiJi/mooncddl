///|
/// A bounded PEG group matcher. A state records consumed input
/// members, so map declaration order never becomes input iteration order.
priv struct GroupMachine {
  context : ValidationContext
  items : Array[(CddlValue, CddlValue)]
  is_map : Bool
  path : String
  mut steps : Int32
  mut exhausted : Bool
  mut cut_failed : Bool
}

///|
fn GroupMachine::tick(self : GroupMachine, depth : Int32) -> Bool {
  self.steps += 1
  if self.steps > self.context.limits.max_tokens() ||
    depth > self.context.limits.max_depth() {
    self.exhausted = true
    false
  } else {
    true
  }
}

///|
fn unique_states(states : Array[Array[Int32]]) -> Array[Array[Int32]] {
  let result : Array[Array[Int32]] = []
  for state in states {
    if !result.contains(state) {
      result.push(state)
    }
  }
  result
}

///|
fn GroupMachine::once(
  self : GroupMachine,
  entry : GroupEntry,
  state : Array[Int32],
  depth : Int32,
) -> Array[Array[Int32]] {
  if !self.tick(depth) {
    return []
  }
  if entry.key() is None {
    match resolve_head(self.context.schema, entry.value(), 0) {
      Some(GroupSchema(alternatives)) => {
        let result : Array[Array[Int32]] = []
        for alternative in alternatives {
          result.append(self.sequence(alternative, [state], depth + 1))
          // RFC 8610 Appendix A: commit the first successful group choice.
          if result.length() > 0 || self.cut_failed || self.exhausted {
            break
          }
        }
        return unique_states(result)
      }
      _ => ()
    }
  }
  let result : Array[Array[Int32]] = []
  for index, item in self.items {
    if state.contains(index) || (!self.is_map && index != state.length()) {
      continue
    }
    let key_matches = match entry.key() {
      Some(key) =>
        !self.is_map ||
        try_validate(self.context, key, item.0, self.path, depth + 1)
      None => !self.is_map
    }
    if !key_matches {
      continue
    }
    let path = if self.is_map {
      map_entry_path(self.path, item.0, index)
    } else {
      self.path + "/" + index.to_string()
    }
    if try_validate(self.context, entry.value(), item.1, path, depth + 1) {
      let next = state.copy()
      next.push(index)
      result.push(next)
    } else if self.is_map && entry.is_cut() {
      self.cut_failed = true
      return []
    }
    if !self.tick(depth) {
      break
    }
  }
  result
}

///|
fn GroupMachine::repeat(
  self : GroupMachine,
  entry : GroupEntry,
  state : Array[Int32],
  depth : Int32,
) -> Array[Array[Int32]] {
  let mut result : Array[Array[Int32]] = []
  let maximum = match entry.occurrence().max() {
    Some(n) => n.min(self.items.length() + 1)
    None => self.items.length() + 1
  }
  let minimum = entry.occurrence().min()
  let mut frontier = [state]
  if minimum == 0 {
    result.push(state)
  }
  for count = 1; count <= maximum; count = count + 1 {
    let next : Array[Array[Int32]] = []
    let stationary : Array[Array[Int32]] = []
    for previous in frontier {
      for current in self.once(entry, previous, depth + 1) {
        // Empty groups may satisfy any finite minimum, but must never spin.
        if current.length() == previous.length() {
          if entry.occurrence().max() is None ||
            entry.occurrence().max().unwrap() >= minimum {
            stationary.push(current)
          }
        } else {
          next.push(current)
        }
      }
      if self.exhausted || self.cut_failed {
        return []
      }
    }
    frontier = unique_states(next)
    if count >= minimum {
      if frontier.length() > 0 {
        result = frontier.copy()
      }
    }
    if stationary.length() > 0 && frontier.length() == 0 {
      return unique_states(stationary)
    }
    if frontier.length() == 0 {
      break
    }
  }
  unique_states(result)
}

///|
fn GroupMachine::sequence(
  self : GroupMachine,
  entries : Array[GroupEntry],
  initial : Array[Array[Int32]],
  depth : Int32,
) -> Array[Array[Int32]] {
  if !self.tick(depth) {
    return []
  }
  let mut states = initial
  for entry in entries {
    let next : Array[Array[Int32]] = []
    for state in states {
      next.append(self.repeat(entry, state, depth + 1))
      if self.exhausted || self.cut_failed {
        return []
      }
    }
    states = unique_states(next)
    if states.length() == 0 {
      break
    }
  }
  states
}

///|
fn match_complete_group(
  context : ValidationContext,
  entries : Array[GroupEntry],
  value : CddlValue,
  path : String,
  depth : Int32,
) -> Bool? {
  let (items, is_map) = match value {
    ArrayValue(values) => {
      let items : Array[(CddlValue, CddlValue)] = []
      for index, item in values {
        items.push((integer_value(index.to_int64()), item))
      }
      (items, false)
    }
    MapValue(items) => (items, true)
    _ => return Some(false)
  }
  if items.length() > context.limits.max_container_items() {
    return None
  }
  let machine : GroupMachine = {
    context,
    items,
    is_map,
    path,
    steps: 0,
    exhausted: false,
    cut_failed: false,
  }
  let states = machine.sequence(entries, [[]], depth + 1)
  if machine.exhausted {
    return None
  }
  Some(states.any(state => state.length() == items.length()))
}
