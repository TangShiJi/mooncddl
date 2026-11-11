///|
priv struct Parser {
  tokens : Array[Token]
  limits : CddlLimits
  mut index : Int
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
fn Parser::peek_kind(self : Parser, distance : Int) -> TokenKind {
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
      Ok(zero_or_more())
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
  depth : Int,
) -> Result[TypeExpr, CddlError] {
  if depth > self.limits.max_depth() {
    return Err(cddl_error(ResourceLimit, "schema nesting exceeds max_depth"))
  }
  match self.current_kind() {
    Identifier(name) => {
      ignore(self.advance())
      match name {
        "true" => Ok(literal(bool_value(true)))
        "false" => Ok(literal(bool_value(false)))
        _ =>
          match primitive_from_name(name) {
            Some(kind) => Ok(primitive(kind))
            None => Ok(reference(name))
          }
      }
    }
    IntegerLiteral(value) => {
      ignore(self.advance())
      Ok(literal(integer_value(value)))
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
      self.skip_newlines()
      let value = match self.parse_expression(depth + 1) {
        Ok(result) => result
        Err(error) => return Err(error)
      }
      self.skip_newlines()
      match self.expect(RParen, "')'") {
        Ok(_) => Ok(value)
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
fn Parser::parse_tag(self : Parser, depth : Int) -> Result[TypeExpr, CddlError] {
  ignore(self.advance())
  match self.current_kind() {
    IntegerLiteral(6L) => ignore(self.advance())
    _ =>
      return Err(self.error("only CBOR tag syntax '#6.n(type)' is supported"))
  }
  match self.expect(Dot, "'.' after #6") {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  let tag = match self.current_kind() {
    IntegerLiteral(value) if value >= 0L => {
      ignore(self.advance())
      value
    }
    _ => return Err(self.error("expected a non-negative CBOR tag number"))
  }
  match self.expect(LParen, "'(' after tag number") {
    Ok(_) => ()
    Err(error) => return Err(error)
  }
  let value = match self.parse_expression(depth + 1) {
    Ok(result) => result
    Err(error) => return Err(error)
  }
  match self.expect(RParen, "')' after tagged type") {
    Ok(_) => Ok(tagged_schema(tag, value))
    Err(error) => Err(error)
  }
}

///|
fn Parser::parse_container(
  self : Parser,
  is_map : Bool,
  depth : Int,
) -> Result[TypeExpr, CddlError] {
  ignore(self.advance())
  let close = if is_map { RBrace } else { RBracket }
  let entries : Array[GroupEntry] = []
  self.skip_newlines()
  while self.current_kind() != close {
    if self.current_kind() == EndOfInput {
      return Err(self.error("unterminated group container"))
    }
    if entries.length() >= self.limits.max_container_items() {
      return Err(cddl_error(ResourceLimit, "group exceeds max_container_items"))
    }
    let cardinality = match self.parse_occurrence() {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if is_map {
      let (key, value) = match (self.current_kind(), self.peek_kind(1)) {
        (Identifier(label), Colon) => {
          ignore(self.advance())
          ignore(self.advance())
          let entry_value = match self.parse_expression(depth + 1) {
            Ok(result) => result
            Err(error) => return Err(error)
          }
          (literal(text_value(label)), entry_value)
        }
        _ => {
          let entry_key = match self.parse_expression(depth + 1) {
            Ok(result) => result
            Err(error) => return Err(error)
          }
          match self.expect(Arrow, "'=>' between map key and value") {
            Ok(_) => ()
            Err(error) => return Err(error)
          }
          let entry_value = match self.parse_expression(depth + 1) {
            Ok(result) => result
            Err(error) => return Err(error)
          }
          (entry_key, entry_value)
        }
      }
      entries.push(group_entry(value, key=Some(key), occurrence=cardinality))
    } else {
      let value = match self.parse_expression(depth + 1) {
        Ok(result) => result
        Err(error) => return Err(error)
      }
      entries.push(group_entry(value, occurrence=cardinality))
    }
    self.skip_newlines()
    if self.current_kind() == Comma {
      ignore(self.advance())
      self.skip_newlines()
    } else if self.current_kind() != close {
      return Err(self.error("expected ',' or the end of the group"))
    }
  }
  ignore(self.advance())
  if is_map {
    Ok(map_schema(entries))
  } else {
    Ok(array_schema(entries))
  }
}

///|
fn Parser::parse_postfix(
  self : Parser,
  depth : Int,
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
        let lower = match integer_literal_from(expression) {
          Some(value) => value
          None =>
            return Err(
              self.error("integer range lower bound must be a literal"),
            )
        }
        let upper = match integer_literal_from(upper_expression) {
          Some(value) => value
          None =>
            return Err(
              self.error("integer range upper bound must be a literal"),
            )
        }
        if upper < lower || (exclusive && upper == lower) {
          return Err(
            cddl_error(
              InvalidRange,
              "range upper bound must be greater than its lower bound",
            ),
          )
        }
        expression = integer_range(lower, upper, exclusive)
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
  depth : Int,
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
    Reference(name) => if has_rule(rules, name) { None } else { Some(name) }
    Choice(items) => {
      for item in items {
        match find_unknown_reference(item, rules) {
          Some(name) => return Some(name)
          None => ()
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
  limits? : CddlLimits = cddl_limits(),
) -> Result[Schema, CddlError] {
  let tokens = match tokenize(source, limits~) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let parser : Parser = { tokens, limits, index: 0 }
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
    if has_rule(rules, name) {
      return Err(
        cddl_error(DuplicateRule, "duplicate rule: " + name, span=Some(span)),
      )
    }
    match parser.expect(Assign, "'=' after rule name") {
      Ok(_) => ()
      Err(error) => return Err(error)
    }
    let value = match parser.parse_expression(0) {
      Ok(result) => result
      Err(error) => return Err(error)
    }
    rules.push(rule(name, value, span))
    if parser.current_kind() != Newline && parser.current_kind() != EndOfInput {
      return Err(parser.error("expected a newline after the rule"))
    }
    parser.skip_newlines()
  }
  if rules.length() == 0 {
    return Err(
      cddl_error(SyntaxError, "CDDL document must contain at least one rule"),
    )
  }
  for item in rules {
    match find_unknown_reference(item.value(), rules) {
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
