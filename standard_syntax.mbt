///|
/// A lossless, syntax-only RFC 8610 document. Syntax acceptance does not imply
/// that every control operator has an implementation in the value validator.
#derive(Debug, Eq)
pub struct StandardSyntax {
  source : String
  rules : Array[String]
  features : Array[String]
}

///|
pub fn StandardSyntax::source(self : StandardSyntax) -> String {
  self.source
}

///|
pub fn StandardSyntax::rule_names(self : StandardSyntax) -> Array[String] {
  self.rules.copy()
}

///|
pub fn StandardSyntax::features(self : StandardSyntax) -> Array[String] {
  self.features.copy()
}

///|
priv struct StandardParser {
  chars : Array[Char]
  limits : CddlLimits
  features : Array[String]
  mut position : Int32
  mut furthest : Int32
  mut operations : Int32
  mut exhausted : Bool
}

///|
fn StandardParser::feature(self : StandardParser, name : String) -> Unit {
  if !self.features.contains(name) {
    self.features.push(name)
  }
}

///|
fn StandardParser::at(self : StandardParser, offset : Int32) -> Char? {
  let index = self.position + offset
  if index < self.chars.length() {
    Some(self.chars[index])
  } else {
    None
  }
}

///|
fn StandardParser::take(self : StandardParser, value : Char) -> Bool {
  if self.at(0) == Some(value) {
    self.position += 1
    self.furthest = self.furthest.max(self.position)
    true
  } else {
    false
  }
}

///|
fn StandardParser::space(self : StandardParser) -> Unit {
  while self.position < self.chars.length() {
    match self.at(0) {
      Some(' ' | '\n') => self.position += 1
      Some('\r') if self.at(1) == Some('\n') => self.position += 2
      Some(';') => {
        self.position += 1
        while self.at(0) is Some(c) && c != '\n' && c != '\r' {
          self.position += 1
        }
      }
      _ => break
    }
  }
}

///|
fn StandardParser::budget(self : StandardParser, depth : Int32) -> Bool {
  self.operations += 1
  // A bounded PEG parser must not turn adversarial ambiguous parentheses into
  // an unbounded retry tree. Budget and nesting failures remain resource errors.
  if depth > self.limits.max_depth() ||
    self.operations.to_int64() > self.limits.max_tokens().to_int64() * 32L {
    self.exhausted = true
    false
  } else {
    true
  }
}

///|
fn StandardParser::identifier(self : StandardParser) -> String? {
  let start = self.position
  if !(self.at(0) is Some(c) && is_identifier_start(c)) {
    return None
  }
  self.position += 1
  while true {
    let mark = self.position
    while self.at(0) == Some('-') || self.at(0) == Some('.') {
      self.position += 1
    }
    if self.at(0) is Some(c) && (is_identifier_start(c) || is_ascii_digit(c)) {
      self.position += 1
    } else {
      self.position = mark
      break
    }
  }
  self.furthest = self.furthest.max(self.position)
  Some(chars_to_string(self.chars[start:self.position].to_owned()))
}

///|
fn StandardParser::digits(self : StandardParser, base : Int32) -> Bool {
  let start = self.position
  while self.at(0) is Some(c) &&
        (if base == 16 {
          is_hex_digit(c)
        } else if base == 2 {
          c == '0' || c == '1'
        } else {
          is_ascii_digit(c)
        }) {
    self.position += 1
  }
  self.furthest = self.furthest.max(self.position)
  self.position > start
}

///|
fn StandardParser::uint(self : StandardParser) -> Bool {
  if self.at(0) == Some('0') &&
    (self.at(1) == Some('x') || self.at(1) == Some('X')) {
    self.position += 2
    return self.digits(16)
  }
  if self.at(0) == Some('0') &&
    (self.at(1) == Some('b') || self.at(1) == Some('B')) {
    self.position += 2
    return self.digits(2)
  }
  if self.take('0') {
    return true
  }
  if self.at(0) is Some(c) && c >= '1' && c <= '9' {
    self.digits(10)
  } else {
    false
  }
}

///|
fn StandardParser::exponent(self : StandardParser) -> Bool {
  if self.at(0) == Some('+') || self.at(0) == Some('-') {
    self.position += 1
  }
  self.digits(10)
}

///|
fn StandardParser::number(self : StandardParser) -> Bool {
  let start = self.position
  ignore(self.take('-'))
  // Hex floats require a binary exponent. A hex integer must leave a following
  // range operator untouched (0x10..0x20).
  if self.at(0) == Some('0') &&
    (self.at(1) == Some('x') || self.at(1) == Some('X')) {
    self.position += 2
    if !self.digits(16) {
      self.position = start
      return false
    }
    if self.at(0) == Some('.') && self.at(1) != Some('.') {
      self.position += 1
      if !self.digits(16) {
        self.position = start
        return false
      }
      if !(self.take('p') || self.take('P')) || !self.exponent() {
        self.position = start
        return false
      }
      self.feature("hex-float")
      return true
    }
    if self.take('p') || self.take('P') {
      if !self.exponent() {
        self.position = start
        return false
      }
      self.feature("hex-float")
    }
    return true
  }
  if !self.uint() {
    self.position = start
    return false
  }
  if self.at(0) == Some('.') && self.at(1) != Some('.') {
    self.position += 1
    if !self.digits(10) {
      self.position = start
      return false
    }
    self.feature("float")
  }
  if self.take('e') || self.take('E') {
    if !self.exponent() {
      self.position = start
      return false
    }
    self.feature("float")
  }
  true
}

///|
fn StandardParser::quoted(self : StandardParser, quote : Char) -> Bool {
  if !self.take(quote) {
    return false
  }
  while self.at(0) is Some(c) {
    self.position += 1
    if c == quote {
      self.furthest = self.furthest.max(self.position)
      return true
    }
    if c == '\\' {
      match self.at(0) {
        Some(escaped) if escaped >= ' ' => self.position += 1
        _ => return false
      }
    } else if c < ' ' {
      if quote == '\'' && c == '\r' && self.at(0) == Some('\n') {
        self.position += 1
      } else if !(quote == '\'' && c == '\n') {
        return false
      }
    }
  }
  false
}

///|
fn StandardParser::value(self : StandardParser) -> Bool {
  let start = self.position
  if self.quoted('"') {
    self.feature("text")
    return true
  }
  self.position = start
  if self.quoted('\'') {
    self.feature("bytes-utf8")
    return true
  }
  self.position = start
  if (self.take('h') || self.take('H')) && self.quoted('\'') {
    self.feature("bytes-hex")
    return true
  }
  self.position = start
  if (self.take('b') || self.take('B')) &&
    self.take('6') &&
    self.take('4') &&
    self.quoted('\'') {
    self.feature("bytes-base64")
    return true
  }
  self.position = start
  self.number()
}

///|
fn StandardParser::generic(
  self : StandardParser,
  parameters : Bool,
  depth : Int32,
) -> Bool {
  if !self.take('<') {
    return false
  }
  self.feature("generics")
  self.space()
  if parameters {
    if self.identifier() is None {
      return false
    }
  } else if !self.type1(depth + 1) {
    return false
  }
  self.space()
  while self.take(',') {
    self.space()
    if parameters {
      if self.identifier() is None {
        return false
      }
    } else if !self.type1(depth + 1) {
      return false
    }
    self.space()
  }
  self.take('>')
}

///|
fn StandardParser::type2(self : StandardParser, depth : Int32) -> Bool {
  if !self.budget(depth) {
    return false
  }
  let start = self.position
  if self.value() {
    return true
  }
  self.position = start
  if self.identifier() is Some(name) {
    if name.has_prefix("$") {
      self.feature("socket-plug")
    }
    self.space()
    if self.at(0) == Some('<') {
      return self.generic(false, depth + 1)
    }
    return true
  }
  self.position = start
  if self.take('(') {
    self.space()
    if !self.type_expr(depth + 1) {
      return false
    }
    self.space()
    return self.take(')')
  }
  if self.at(0) == Some('{') || self.at(0) == Some('[') {
    let is_map = self.take('{')
    if !is_map {
      ignore(self.take('['))
    }
    self.feature(if is_map { "map" } else { "array" })
    self.space()
    if !self.group(depth + 1) {
      return false
    }
    return self.take(if is_map { '}' } else { ']' })
  }
  if self.take('~') {
    self.feature("unwrap")
    self.space()
    if self.identifier() is None {
      return false
    }
    self.space()
    if self.at(0) == Some('<') {
      return self.generic(false, depth + 1)
    }
    return true
  }
  if self.take('&') {
    self.feature("enumeration")
    self.space()
    if self.take('(') {
      self.space()
      if !self.group(depth + 1) {
        return false
      }
      return self.take(')')
    }
    if self.identifier() is None {
      return false
    }
    self.space()
    if self.at(0) == Some('<') {
      return self.generic(false, depth + 1)
    }
    return true
  }
  if self.take('#') {
    self.feature("major-type")
    let tagged = self.at(0) == Some('6')
    let has_major = self.at(0) is Some(c) && is_ascii_digit(c)
    if !has_major {
      return true
    }
    self.position += 1
    if self.take('.') && !self.uint() {
      return false
    }
    if tagged && self.take('(') {
      self.feature("tag")
      self.space()
      if !self.type_expr(depth + 1) {
        return false
      }
      self.space()
      return self.take(')')
    }
    return true
  }
  false
}

///|
fn StandardParser::type1(self : StandardParser, depth : Int32) -> Bool {
  if !self.type2(depth + 1) {
    return false
  }
  self.space()
  if self.take('.') {
    if self.take('.') {
      ignore(self.take('.'))
      self.feature("range")
    } else {
      match self.identifier() {
        Some(name) => self.feature("control:" + name)
        None => return false
      }
    }
    self.space()
    return self.type2(depth + 1)
  }
  true
}

///|
fn StandardParser::type_expr(self : StandardParser, depth : Int32) -> Bool {
  if !self.type1(depth + 1) {
    return false
  }
  self.space()
  while self.at(0) == Some('/') &&
        self.at(1) != Some('/') &&
        self.at(1) != Some('=') {
    self.position += 1
    self.feature("type-choice")
    self.space()
    if !self.type1(depth + 1) {
      return false
    }
    self.space()
  }
  true
}

///|
fn StandardParser::occur(self : StandardParser) -> Bool {
  if self.take('?') || self.take('+') {
    self.feature("occurrence")
    return true
  }
  let start = self.position
  ignore(self.uint())
  if self.take('*') {
    ignore(self.uint())
    self.feature("occurrence")
    true
  } else {
    self.position = start
    false
  }
}

///|
fn StandardParser::memberkey(self : StandardParser, depth : Int32) -> Bool {
  let start = self.position
  if self.identifier() is Some(_) {
    self.space()
    if self.take(':') {
      self.feature("label")
      return true
    }
  }
  self.position = start
  if self.value() {
    self.space()
    if self.take(':') {
      self.feature("value-key")
      return true
    }
  }
  self.position = start
  if self.type1(depth + 1) {
    self.space()
    if self.take('^') {
      self.feature("cut")
      self.space()
    }
    if self.take('=') && self.take('>') {
      self.feature("typed-key")
      return true
    }
  }
  self.position = start
  false
}

///|
fn StandardParser::grpent(self : StandardParser, depth : Int32) -> Bool {
  if !self.budget(depth) {
    return false
  }
  ignore(self.occur())
  self.space()
  let start = self.position
  let keyed = self.memberkey(depth + 1)
  self.space()
  if self.type_expr(depth + 1) {
    return true
  }
  if keyed {
    return false
  }
  self.position = start
  if self.take('(') {
    self.feature("named-group")
    self.space()
    if !self.group(depth + 1) {
      return false
    }
    return self.take(')')
  }
  false
}

///|
fn StandardParser::group(self : StandardParser, depth : Int32) -> Bool {
  if !self.budget(depth) {
    return false
  }
  while true {
    self.space()
    let mark = self.position
    if self.grpent(depth + 1) {
      if self.position == mark {
        return false
      }
      self.space()
      ignore(self.take(','))
    } else {
      self.position = mark
      if self.take('/') && self.take('/') {
        self.feature("group-choice")
      } else {
        self.position = mark
        break
      }
    }
  }
  self.space()
  true
}

///|
fn StandardParser::rule(self : StandardParser) -> String? {
  let name = match self.identifier() {
    Some(n) => n
    None => return None
  }
  self.space()
  if self.at(0) == Some('<') && !self.generic(true, 0) {
    return None
  }
  self.space()
  let mut group_only = false
  if self.take('/') {
    group_only = self.take('/')
    self.feature(if group_only { "group-extension" } else { "type-extension" })
  }
  if !self.take('=') {
    return None
  }
  self.space()
  let start = self.position
  if !group_only && self.type_expr(0) {
    return Some(name)
  }
  self.position = start
  if self.grpent(0) {
    Some(name)
  } else {
    None
  }
}

///|
/// Check the complete normative Appendix B grammar, independently of numeric
/// storage limits or runtime feature support. Name resolution and controller
/// semantics deliberately belong to parse_cddl/validate, not this syntax API.
pub fn check_standard_syntax(
  source : String,
  limits~ : CddlLimits = cddl_limits(),
) -> Result[StandardSyntax, CddlError] {
  if @utf8.encode(source[:]).length() > limits.max_source_bytes() {
    return Err(
      cddl_error(ResourceLimit, "CDDL source exceeds max_source_bytes"),
    )
  }
  let parser : StandardParser = {
    chars: source.to_array(),
    limits,
    features: [],
    position: 0,
    furthest: 0,
    operations: 0,
    exhausted: false,
  }
  let rules : Array[String] = []
  parser.space()
  while parser.position < parser.chars.length() {
    if rules.length() >= limits.max_rules() {
      return Err(cddl_error(ResourceLimit, "CDDL source exceeds max_rules"))
    }
    match parser.rule() {
      Some(name) => rules.push(name)
      None => {
        if parser.exhausted {
          return Err(
            cddl_error(
              ResourceLimit,
              "standard grammar nesting or operation limit reached",
            ),
          )
        }
        let mut line = 1
        let mut column = 1
        for index = 0; index < parser.furthest; index = index + 1 {
          if parser.chars[index] == '\n' {
            line += 1
            column = 1
          } else {
            column += 1
          }
        }
        return Err(
          cddl_error(
            SyntaxError,
            "expected RFC 8610 Appendix B syntax",
            span=Some(
              source_span(parser.furthest, parser.furthest, line, column),
            ),
          ),
        )
      }
    }
    parser.space()
  }
  if rules.is_empty() {
    return Err(cddl_error(SyntaxError, "CDDL requires at least one rule"))
  }
  Ok({ source, rules, features: parser.features, })
}
