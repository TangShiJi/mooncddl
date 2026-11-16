///|
priv struct Parser {
  tokens : Array[Token]
  limits : CddlLimits
  mut index : Int32
}

///|
fn Parser::current(self : Parser) -> Token {
  self.tokens[self.index]
}

///|
fn Parser::current_kind(self : Parser) -> TokenKind {
  self.current().kind()
}

///|
fn Parser::advance(self : Parser) -> Token {
  let value = self.current()
  if self.index + 1 < self.tokens.length() {
    self.index += 1
  }
  value
}

///|
fn Parser::peek_kind(self : Parser, distance : Int32) -> TokenKind {
  let position = self.index + distance
  if position < self.tokens.length() {
    self.tokens[position].kind()
  } else {
    EndOfInput
  }
}

///|
fn Parser::skip_newlines(self : Parser) -> Unit {
  while self.current_kind() == Newline {
    ignore(self.advance())
  }
}

///|
fn Parser::error(self : Parser, message : String) -> CddlError {
  cddl_error(SyntaxError, message, span=Some(self.current().span()))
}

///|
fn Parser::expect(
  self : Parser,
  expected : TokenKind,
  label : String,
) -> Result[Token, CddlError] {
  if self.current_kind() == expected {
    Ok(self.advance())
  } else {
    Err(self.error("expected " + label))
  }
}

///|
fn Parser::parse_occurrence(self : Parser) -> Result[Occurrence, CddlError] {
  match self.current_kind() {
    Question => {
      ignore(self.advance())
      Ok(optional())
    }
    Plus => {
      ignore(self.advance())
      Ok(one_or_more())
    }
    Star => {
      ignore(self.advance())
      match self.current_kind() {
        IntegerLiteral(maximum) if maximum >= 0L && maximum <= 2147483647L => {
          ignore(self.advance())
          Ok(occurrence(0, Some(maximum.to_int())))
        }
        _ => Ok(zero_or_more())
      }
    }
    IntegerLiteral(minimum) if self.peek_kind(1) == Star => {
      if minimum < 0L || minimum > 2147483647L {
        return Err(
          cddl_error(
            InvalidOccurrence,
            "occurrence lower bound must be a non-negative Int",
            span=Some(self.current().span()),
          ),
        )
      }
      ignore(self.advance())
      ignore(self.advance())
      match self.current_kind() {
        IntegerLiteral(maximum) => {
          if maximum < minimum || maximum > 2147483647L {
            return Err(
              cddl_error(
                InvalidOccurrence,
                "occurrence upper bound must be at least the lower bound",
                span=Some(self.current().span()),
              ),
            )
          }
          ignore(self.advance())
          Ok(occurrence(minimum.to_int(), Some(maximum.to_int())))
        }
        _ => Ok(occurrence(minimum.to_int(), None))
      }
    }
    _ => Ok(once())
  }
}

///|
fn integer_literal_from(expression : TypeExpr) -> Int64? {
  match expression {
    Literal(IntegerValue(value)) => Some(value)
    _ => None
  }
}

///|
fn Parser::parse_primary(
  self : Parser,
  depth : Int32,
) -> Result[TypeExpr, CddlError] {
  if depth > self.limits.max_depth() {
    return Err(cddl_error(ResourceLimit, "schema nesting exceeds max_depth"))
  }
  match self.current_kind() {
    Identifier(name) => {
      ignore(self.advance())
      if self.current_kind() == LessAngle {
        ignore(self.advance())
        self.skip_newlines()
        let arguments : Array[TypeExpr] = []
        while true {
          match self.parse_postfix(depth + 1) {
            Ok(value) => arguments.push(value)
            Err(error) => return Err(error)
          }
          self.skip_newlines()
          if self.current_kind() != Comma {
            break
          }
          ignore(self.advance())
          self.skip_newlines()
        }
        match self.expect(GreaterAngle, "'>' after generic arguments") {
          Ok(_) => return Ok(Application(name, arguments))
          Err(error) => return Err(error)
        }
      }
      Ok(reference(name))
    }
    IntegerLiteral(value) => {
      ignore(self.advance())
      Ok(literal(integer_value(value)))
    }
    NumberLiteral(value) => {
      ignore(self.advance())
      Ok(literal(value))
    }
    TextLiteral(value) => {
      ignore(self.advance())
      Ok(literal(text_value(value)))
    }
    ByteLiteral(value) => {
      ignore(self.advance())
      Ok(literal(bytes_value(value)))
    }
    LParen => {
      ignore(self.advance())
      let alternatives = match self.parse_group(RParen, depth + 1) {
        Ok(result) => result
        Err(error) => return Err(error)
      }
      match self.expect(RParen, "')'") {
        Ok(_) => {
          if alternatives.length() == 1 && alternatives[0].length() == 1 {
            let entry = alternatives[0][0]
            if entry.key() is None && entry.occurrence() == once() {
              return Ok(entry.value())
            }
          }
          Ok(GroupSchema(alternatives))
        }
        Err(error) => Err(error)
      }
    }
    Tilde | Ampersand => {
      let unwrap = self.current_kind() == Tilde
      ignore(self.advance())
      self.skip_newlines()
      match self.parse_primary(depth + 1) {
        Ok(value) => Ok(if unwrap { Unwrap(value) } else { Enumeration(value) })
        Err(error) => Err(error)
      }
    }
    LBracket => self.parse_container(false, depth + 1)
    LBrace => self.parse_container(true, depth + 1)
    Hash => self.parse_tag(depth + 1)
    _ => Err(self.error("expected a CDDL type expression"))
  }
}

///|
fn Parser::parse_tag(
  self : Parser,
  depth : Int32,
) -> Result[TypeExpr, CddlError] {
  ignore(self.advance())
  let major = match self.current_kind() {
    IntegerLiteral(n) if n >= 0L && n <= 7L => {
      ignore(self.advance())
      n.to_int()
    }
    IntegerLiteral(_) =>
      return Err(self.error("CBOR major type must be 0 through 7"))
    _ => return Ok(Primitive(AnyType))
  }
  let mut argument : UInt64? = None
  if self.current_kind() == Dot {
    ignore(self.advance())
    argument = match self.current_kind() {
      IntegerLiteral(n) if n >= 0L => Some(n.reinterpret_as_uint64())
      NumberLiteral(UnsignedValue(n)) => Some(n)
      _ =>
        return Err(self.error("expected unsigned CBOR additional information"))
    }
    ignore(self.advance())
  }
  if major != 6 || self.current_kind() != LParen {
    return Ok(MajorSchema(major, argument))
  }
  ignore(self.advance())
  let value = match self.parse_expression(depth + 1) {
    Ok(result) => result
    Err(error) => return Err(error)
  }
  match self.expect(RParen, "')' after tagged type") {
    Ok(_) =>
      match argument {
        Some(tag) if tag <= 9223372036854775807UL =>
          Ok(tagged_schema(tag.reinterpret_as_int64(), value))
        _ => Ok(Controlled(MajorSchema(6, argument), TagContentControl, value))
      }
    Err(error) => Err(error)
  }
}

///|
fn Parser::parse_container(
  self : Parser,
  is_map : Bool,
  depth : Int32,
) -> Result[TypeExpr, CddlError] {
  ignore(self.advance())
  let close = if is_map { RBrace } else { RBracket }
  let alternatives = match self.parse_group(close, depth + 1) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  match self.expect(close, "container closing delimiter") {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  let entries = if alternatives.length() == 1 {
    alternatives[0]
  } else {
    [group_entry(GroupSchema(alternatives))]
  }
  Ok(if is_map { map_schema(entries) } else { array_schema(entries) })
}

///|
fn Parser::parse_group(
  self : Parser,
  close : TokenKind,
  depth : Int32,
) -> Result[Array[Array[GroupEntry]], CddlError] {
  if depth > self.limits.max_depth() {
    return Err(cddl_error(ResourceLimit, "group nesting exceeds max_depth"))
  }
  let alternatives : Array[Array[GroupEntry]] = []
  let mut entries : Array[GroupEntry] = []
  self.skip_newlines()
  while self.current_kind() != close {
    if self.current_kind() == EndOfInput {
      return Err(self.error("unterminated group container"))
    }
    if entries.length() >= self.limits.max_container_items() {
      return Err(cddl_error(ResourceLimit, "group exceeds max_container_items"))
    }
    if self.current_kind() == GroupChoice {
      alternatives.push(entries)
      entries = []
      ignore(self.advance())
      self.skip_newlines()
      continue
    }
    let entry = match self.parse_entry(depth + 1) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    entries.push(entry)
    self.skip_newlines()
    if self.current_kind() == Comma {
      ignore(self.advance())
      self.skip_newlines()
    }
  }
  alternatives.push(entries)
  Ok(alternatives)
}

///|
fn Parser::parse_entry(
  self : Parser,
  depth : Int32,
) -> Result[GroupEntry, CddlError] {
  let cardinality = match self.parse_occurrence() {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let (key, value, cut) = match (self.current_kind(), self.peek_kind(1)) {
    (Identifier(label), Colon) => {
      ignore(self.advance())
      ignore(self.advance())
      let entry_value = match self.parse_expression(depth + 1) {
        Ok(result) => result
        Err(error) => return Err(error)
      }
      (Some(literal(text_value(label))), entry_value, true)
    }
    _ => {
      let entry_key = match self.parse_expression(depth + 1) {
        Ok(result) => result
        Err(error) => return Err(error)
      }
      let cut = self.current_kind() == Cut || self.current_kind() == Colon
      if self.current_kind() == Cut {
        ignore(self.advance())
      }
      if self.current_kind() != Arrow && self.current_kind() != Colon {
        return Ok(group_entry(entry_key, occurrence=cardinality))
      }
      ignore(self.advance())
      let entry_value = match self.parse_expression(depth + 1) {
        Ok(result) => result
        Err(error) => return Err(error)
      }
      (Some(entry_key), entry_value, cut)
    }
  }
  Ok(group_entry(value, key~, occurrence=cardinality, cut~))
}

///|
fn Parser::parse_postfix(
  self : Parser,
  depth : Int32,
) -> Result[TypeExpr, CddlError] {
  let mut expression = match self.parse_primary(depth + 1) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  while true {
    match self.current_kind() {
      RangeInclusive | RangeExclusive => {
        let exclusive = self.current_kind() == RangeExclusive
        ignore(self.advance())
        let upper_expression = match self.parse_primary(depth + 1) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        expression = match (expression, upper_expression) {
          (Literal(IntegerValue(a)), Literal(IntegerValue(b))) =>
            IntegerRange(a, b, exclusive)
          (Literal(a), Literal(b)) => ValueRange(a, b, exclusive)
          (a, b) => DynamicRange(a, b, exclusive)
        }
      }
      Control(name) => {
        let operator = match control_from_name(name) {
          Some(value) => value
          None =>
            return Err(
              cddl_error(
                UnsupportedFeature,
                "unsupported CDDL control operator: ." + name,
                span=Some(self.current().span()),
              ),
            )
        }
        ignore(self.advance())
        let mut argument = match self.parse_primary(depth + 1) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        if self.current_kind() == RangeInclusive ||
          self.current_kind() == RangeExclusive {
          let exclusive = self.current_kind() == RangeExclusive
          ignore(self.advance())
          let upper_expression = match self.parse_primary(depth + 1) {
            Ok(value) => value
            Err(error) => return Err(error)
          }
          let lower = match integer_literal_from(argument) {
            Some(value) => value
            None =>
              return Err(
                self.error(
                  "control range lower bound must be an integer literal",
                ),
              )
          }
          let upper = match integer_literal_from(upper_expression) {
            Some(value) => value
            None =>
              return Err(
                self.error(
                  "control range upper bound must be an integer literal",
                ),
              )
          }
          argument = integer_range(lower, upper, exclusive)
        }
        expression = controlled(expression, operator, argument)
      }
      _ => return Ok(expression)
    }
  } nobreak {
    Ok(expression)
  }
}

///|
fn Parser::parse_expression(
  self : Parser,
  depth : Int32,
) -> Result[TypeExpr, CddlError] {
  let first = match self.parse_postfix(depth + 1) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if self.current_kind() != TypeChoice {
    return Ok(first)
  }
  let alternatives : Array[TypeExpr] = [first]
  while self.current_kind() == TypeChoice {
    ignore(self.advance())
    match self.parse_postfix(depth + 1) {
      Ok(value) => alternatives.push(value)
      Err(error) => return Err(error)
    }
  }
  Ok(choice(alternatives))
}

///|
fn has_rule(rules : Array[Rule], name : String) -> Bool {
  for item in rules {
    if item.name() == name {
      return true
    }
  }
  false
}

///|
fn find_unknown_reference(
  expression : TypeExpr,
  rules : Array[Rule],
) -> String? {
  match expression {
    Reference(name) =>
      if has_rule(rules, name) ||
        name.has_prefix("$") ||
        prelude_expression(name) is Some(_) {
        None
      } else {
        Some(name)
      }
    Choice(items) => {
      for item in items {
        match find_unknown_reference(item, rules) {
          Some(name) => return Some(name)
          None => ()
        }
      }
      None
    }
    Application(name, arguments) => {
      if !has_rule(rules, name) {
        return Some(name)
      }
      for item in arguments {
        if find_unknown_reference(item, rules) is Some(missing) {
          return Some(missing)
        }
      }
      None
    }
    Unwrap(value) | Enumeration(value) => find_unknown_reference(value, rules)
    DynamicRange(lower, upper, _) =>
      match find_unknown_reference(lower, rules) {
        Some(name) => Some(name)
        None => find_unknown_reference(upper, rules)
      }
    GroupSchema(alternatives) => {
      for entries in alternatives {
        if find_unknown_reference(ArraySchema(entries), rules) is Some(missing) {
          return Some(missing)
        }
      }
      None
    }
    ArraySchema(entries) | MapSchema(entries) => {
      for entry in entries {
        match entry.key() {
          Some(key) =>
            match find_unknown_reference(key, rules) {
              Some(name) => return Some(name)
              None => ()
            }
          None => ()
        }
        match find_unknown_reference(entry.value(), rules) {
          Some(name) => return Some(name)
          None => ()
        }
      }
      None
    }
    TaggedSchema(_, value) => find_unknown_reference(value, rules)
    Controlled(target, _, argument) =>
      match find_unknown_reference(target, rules) {
        Some(name) => Some(name)
        None => find_unknown_reference(argument, rules)
      }
    _ => None
  }
}

///|
/// Parse a complete CDDL document, reject duplicate rules and resolve every
/// named reference before returning an immutable schema.
pub fn parse_cddl(
  source : String,
  limits~ : CddlLimits = cddl_limits(),
) -> Result[Schema, CddlError] {
  match check_standard_syntax(source, limits~) {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  let tokens = match tokenize(source, limits~) {
    Ok(value) => value.filter(token => token.kind() != Newline)
    Err(error) => return Err(error)
  }
  let parser : Parser = { tokens, limits, index: 0, }
  let rules : Array[Rule] = []
  parser.skip_newlines()
  while parser.current_kind() != EndOfInput {
    if rules.length() >= limits.max_rules() {
      return Err(cddl_error(ResourceLimit, "schema exceeds max_rules"))
    }
    let (name, span) = match parser.current_kind() {
      Identifier(value) => {
        let token = parser.advance()
        (value, token.span())
      }
      _ => return Err(parser.error("expected a rule name"))
    }
    let parameters : Array[String] = []
    if parser.current_kind() == LessAngle {
      ignore(parser.advance())
      parser.skip_newlines()
      while true {
        match parser.current_kind() {
          Identifier(parameter) => {
            if parameters.contains(parameter) {
              return Err(parser.error("duplicate generic parameter"))
            }
            parameters.push(parameter)
            ignore(parser.advance())
          }
          _ => return Err(parser.error("expected generic parameter name"))
        }
        parser.skip_newlines()
        if parser.current_kind() != Comma {
          break
        }
        ignore(parser.advance())
        parser.skip_newlines()
      }
      match parser.expect(GreaterAngle, "'>' after generic parameters") {
        Ok(_) => ()
        Err(error) => return Err(error)
      }
    }
    let extension = parser.current_kind() == TypeChoice ||
      parser.current_kind() == GroupChoice
    let group_extension = parser.current_kind() == GroupChoice
    if extension {
      ignore(parser.advance())
    }
    match parser.expect(Assign, "'=' after rule name") {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
    parser.skip_newlines()
    let value = match parser.parse_entry(0) {
      Ok(entry) =>
        if entry.key() is None && entry.occurrence() == once() {
          entry.value()
        } else {
          GroupSchema([[entry]])
        }
      Err(error) => return Err(error)
    }
    if has_rule(rules, name) && !extension {
      let same = rules.any(previous => {
        previous.name() == name &&
        previous.value() == value &&
        previous.parameters() == parameters
      })
      if same {
        continue
      }
      return Err(
        cddl_error(DuplicateRule, "conflicting rule: " + name, span=Some(span)),
      )
    }
    if extension && has_rule(rules, name) {
      for index, previous in rules {
        if previous.name() == name {
          if previous.parameters() != parameters {
            return Err(parser.error("generic extension parameters differ"))
          }
          let merged = if group_extension {
            GroupSchema([as_group(previous.value()), as_group(value)])
          } else {
            choice([previous.value(), value])
          }
          rules[index] = rule(name, merged, previous.span(), parameters~)
          break
        }
      }
    } else {
      rules.push(rule(name, value, span, parameters~))
    }
    parser.skip_newlines()
  }
  if rules.length() == 0 {
    return Err(
      cddl_error(SyntaxError, "CDDL document must contain at least one rule"),
    )
  }
  for item in rules {
    let scope = rules.copy()
    for parameter in item.parameters() {
      scope.push(rule(parameter, primitive(AnyType), item.span()))
    }
    match find_unknown_reference(item.value(), scope) {
      Some(name) =>
        return Err(
          cddl_error(
            UnknownRule,
            "unknown referenced rule '" + name + "' in '" + item.name() + "'",
          ),
        )
      None => ()
    }
  }
  Ok(schema(rules))
}
