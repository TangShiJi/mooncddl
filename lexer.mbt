///|
/// Lexical units retained by the parser. Newlines are significant at the top
/// level because CDDL rules do not require a trailing delimiter.
pub(all) enum TokenKind {
  Identifier(String)
  IntegerLiteral(Int64)
  TextLiteral(String)
  ByteLiteral(Bytes)
  Control(String)
  Dot
  Assign
  TypeChoice
  GroupChoice
  RangeInclusive
  RangeExclusive
  Arrow
  LBrace
  RBrace
  LBracket
  RBracket
  LParen
  RParen
  Colon
  Comma
  Question
  Star
  Plus
  Hash
  Newline
  EndOfInput
} derive(Debug, Eq)

///|
pub struct Token {
  kind : TokenKind
  span : SourceSpan
} derive(Debug, Eq)

///|
pub fn Token::kind(self : Token) -> TokenKind {
  self.kind
}

///|
pub fn Token::span(self : Token) -> SourceSpan {
  self.span
}

///|
priv struct Lexer {
  chars : Array[Char]
  limits : CddlLimits
  mut index : Int
  mut line : Int
  mut column : Int
}

///|
fn Lexer::peek(self : Lexer) -> Char? {
  if self.index < self.chars.length() {
    Some(self.chars[self.index])
  } else {
    None
  }
}

///|
fn Lexer::peek_next(self : Lexer) -> Char? {
  if self.index + 1 < self.chars.length() {
    Some(self.chars[self.index + 1])
  } else {
    None
  }
}

///|
fn Lexer::advance(self : Lexer) -> Char? {
  match self.peek() {
    None => None
    Some(value) => {
      self.index += 1
      if value == '\n' {
        self.line += 1
        self.column = 1
      } else {
        self.column += 1
      }
      Some(value)
    }
  }
}

///|
fn Lexer::token(
  self : Lexer,
  kind : TokenKind,
  start : Int,
  line : Int,
  column : Int,
) -> Token {
  { kind, span: source_span(start, self.index, line, column) }
}

///|
fn is_ascii_digit(value : Char) -> Bool {
  value >= '0' && value <= '9'
}

///|
fn is_hex_digit(value : Char) -> Bool {
  is_ascii_digit(value) ||
  (value >= 'a' && value <= 'f') ||
  (value >= 'A' && value <= 'F')
}

///|
fn digit_value(value : Char) -> Int {
  if value >= '0' && value <= '9' {
    value.to_int() - '0'.to_int()
  } else if value >= 'a' && value <= 'f' {
    value.to_int() - 'a'.to_int() + 10
  } else {
    value.to_int() - 'A'.to_int() + 10
  }
}

///|
fn is_identifier_start(value : Char) -> Bool {
  (value >= 'a' && value <= 'z') ||
  (value >= 'A' && value <= 'Z') ||
  value == '_' ||
  value == '$' ||
  value == '@'
}

///|
fn is_identifier_continue(value : Char) -> Bool {
  is_identifier_start(value) || is_ascii_digit(value) || value == '-'
}

///|
fn chars_to_string(chars : Array[Char]) -> String {
  String::from_array(chars)
}

///|
fn lex_error(message : String, span : SourceSpan) -> CddlError {
  cddl_error(LexicalError, message, span=Some(span))
}

///|
fn Lexer::read_identifier(
  self : Lexer,
  start : Int,
  line : Int,
  column : Int,
) -> Token {
  while (match self.peek() {
          Some(value) => is_identifier_continue(value)
          None => false
        }) {
    ignore(self.advance())
  }
  let value = chars_to_string(self.chars[start:self.index].to_owned())
  self.token(Identifier(value), start, line, column)
}

///|
fn Lexer::read_control(
  self : Lexer,
  start : Int,
  line : Int,
  column : Int,
) -> Result[Token, CddlError] {
  ignore(self.advance())
  let name_start = self.index
  while (match self.peek() {
          Some(value) => is_identifier_continue(value)
          None => false
        }) {
    ignore(self.advance())
  }
  if name_start == self.index {
    Err(
      lex_error(
        "expected control operator name after '.'",
        source_span(start, self.index, line, column),
      ),
    )
  } else {
    let value = chars_to_string(self.chars[name_start:self.index].to_owned())
    Ok(self.token(Control(value), start, line, column))
  }
}

///|
fn checked_digit_append(
  current : Int64,
  digit : Int,
  base : Int64,
  negative : Bool,
) -> Int64? {
  let next_digit = digit.to_int64()
  if negative {
    if current < (@int64.MIN_VALUE + next_digit) / base {
      None
    } else {
      Some(current * base - next_digit)
    }
  } else if current > (@int64.MAX_VALUE - next_digit) / base {
    None
  } else {
    Some(current * base + next_digit)
  }
}

///|
fn Lexer::read_integer(
  self : Lexer,
  start : Int,
  line : Int,
  column : Int,
) -> Result[Token, CddlError] {
  let negative = self.peek() == Some('-')
  if negative {
    ignore(self.advance())
  }
  let mut base = 10
  if self.peek() == Some('0') && self.peek_next() == Some('x') {
    base = 16
    ignore(self.advance())
    ignore(self.advance())
  } else if self.peek() == Some('0') && self.peek_next() == Some('b') {
    base = 2
    ignore(self.advance())
    ignore(self.advance())
  }
  let digit_start = self.index
  let mut value = 0L
  let mut digits = 0
  while self.peek() is Some(_) {
    let current = self.peek().unwrap()
    if current == '_' {
      ignore(self.advance())
      continue
    }
    let valid = if base == 16 {
      is_hex_digit(current)
    } else if base == 2 {
      current == '0' || current == '1'
    } else {
      is_ascii_digit(current)
    }
    if !valid {
      break
    }
    match
      checked_digit_append(
        value,
        digit_value(current),
        base.to_int64(),
        negative,
      ) {
      None =>
        return Err(
          lex_error(
            "integer literal is outside the signed 64-bit range",
            source_span(start, self.index + 1, line, column),
          ),
        )
      Some(next) => value = next
    }
    digits += 1
    ignore(self.advance())
  }
  if digit_start == self.index || digits == 0 {
    Err(
      lex_error(
        "expected digits in integer literal",
        source_span(start, self.index, line, column),
      ),
    )
  } else {
    Ok(self.token(IntegerLiteral(value), start, line, column))
  }
}

///|
fn Lexer::read_text(
  self : Lexer,
  start : Int,
  line : Int,
  column : Int,
) -> Result[Token, CddlError] {
  ignore(self.advance())
  let output : Array[Char] = []
  while self.peek() is Some(_) {
    let current = self.advance().unwrap()
    if current == '"' {
      return Ok(
        self.token(TextLiteral(chars_to_string(output)), start, line, column),
      )
    }
    if current == '\n' || current == '\r' {
      return Err(
        lex_error(
          "text literal cannot contain an unescaped newline",
          source_span(start, self.index, line, column),
        ),
      )
    }
    if current == '\\' {
      let escaped = match self.advance() {
        Some('"') => '"'
        Some('\\') => '\\'
        Some('/') => '/'
        Some('b') => '\b'
        Some('f') => '\f'
        Some('n') => '\n'
        Some('r') => '\r'
        Some('t') => '\t'
        Some(other) =>
          return Err(
            lex_error(
              "unsupported escape sequence: \\" + other.to_string(),
              source_span(start, self.index, line, column),
            ),
          )
        None =>
          return Err(
            lex_error(
              "unterminated escape sequence",
              source_span(start, self.index, line, column),
            ),
          )
      }
      output.push(escaped)
    } else {
      output.push(current)
    }
  }
  Err(
    lex_error(
      "unterminated text literal",
      source_span(start, self.index, line, column),
    ),
  )
}

///|
fn Lexer::read_hex_bytes(
  self : Lexer,
  start : Int,
  line : Int,
  column : Int,
) -> Result[Token, CddlError] {
  ignore(self.advance())
  ignore(self.advance())
  let output : Array[Byte] = []
  let mut high : Int? = None
  while self.peek() is Some(_) {
    let current = self.advance().unwrap()
    if current == '\'' {
      match high {
        Some(_) =>
          return Err(
            lex_error(
              "hex byte string must contain an even number of digits",
              source_span(start, self.index, line, column),
            ),
          )
        None =>
          return Ok(
            self.token(
              ByteLiteral(Bytes::from_array(output[:])),
              start,
              line,
              column,
            ),
          )
      }
    }
    if current == ' ' || current == '\t' || current == '\n' || current == '\r' {
      continue
    }
    if !is_hex_digit(current) {
      return Err(
        lex_error(
          "invalid character in hex byte string",
          source_span(start, self.index, line, column),
        ),
      )
    }
    match high {
      None => high = Some(digit_value(current))
      Some(value) => {
        output.push(((value * 16 + digit_value(current)) & 0xff).to_byte())
        high = None
      }
    }
  }
  Err(
    lex_error(
      "unterminated hex byte string",
      source_span(start, self.index, line, column),
    ),
  )
}

///|
fn Lexer::skip_comment(self : Lexer) -> Unit {
  while (match self.peek() {
          Some(value) => value != '\n'
          None => false
        }) {
    ignore(self.advance())
  }
}

///|
fn Lexer::next_token(self : Lexer) -> Result[Token, CddlError] {
  while (match self.peek() {
          Some(value) => value == ' ' || value == '\t' || value == '\r'
          None => false
        }) {
    ignore(self.advance())
  }
  if self.peek() == Some(';') {
    self.skip_comment()
    return self.next_token()
  }
  let start = self.index
  let line = self.line
  let column = self.column
  match self.peek() {
    None => Ok(self.token(EndOfInput, start, line, column))
    Some('\n') => {
      ignore(self.advance())
      Ok(self.token(Newline, start, line, column))
    }
    Some('h') if self.peek_next() == Some('\'') =>
      self.read_hex_bytes(start, line, column)
    Some(value) if is_identifier_start(value) =>
      Ok(self.read_identifier(start, line, column))
    Some(value) if is_ascii_digit(value) =>
      self.read_integer(start, line, column)
    Some('-') if (match self.peek_next() {
        Some(value) => is_ascii_digit(value)
        None => false
      }) => self.read_integer(start, line, column)
    Some('"') => self.read_text(start, line, column)
    Some('.') if self.peek_next() == Some('.') => {
      ignore(self.advance())
      ignore(self.advance())
      if self.peek() == Some('.') {
        ignore(self.advance())
        Ok(self.token(RangeExclusive, start, line, column))
      } else {
        Ok(self.token(RangeInclusive, start, line, column))
      }
    }
    Some('.') =>
      match self.peek_next() {
        Some(value) if is_ascii_digit(value) => {
          ignore(self.advance())
          Ok(self.token(Dot, start, line, column))
        }
        _ => self.read_control(start, line, column)
      }
    Some('=') => {
      ignore(self.advance())
      if self.peek() == Some('>') {
        ignore(self.advance())
        Ok(self.token(Arrow, start, line, column))
      } else {
        Ok(self.token(Assign, start, line, column))
      }
    }
    Some('/') => {
      ignore(self.advance())
      if self.peek() == Some('/') {
        ignore(self.advance())
        Ok(self.token(GroupChoice, start, line, column))
      } else {
        Ok(self.token(TypeChoice, start, line, column))
      }
    }
    Some('{') => {
      ignore(self.advance())
      Ok(self.token(LBrace, start, line, column))
    }
    Some('}') => {
      ignore(self.advance())
      Ok(self.token(RBrace, start, line, column))
    }
    Some('[') => {
      ignore(self.advance())
      Ok(self.token(LBracket, start, line, column))
    }
    Some(']') => {
      ignore(self.advance())
      Ok(self.token(RBracket, start, line, column))
    }
    Some('(') => {
      ignore(self.advance())
      Ok(self.token(LParen, start, line, column))
    }
    Some(')') => {
      ignore(self.advance())
      Ok(self.token(RParen, start, line, column))
    }
    Some(':') => {
      ignore(self.advance())
      Ok(self.token(Colon, start, line, column))
    }
    Some(',') => {
      ignore(self.advance())
      Ok(self.token(Comma, start, line, column))
    }
    Some('?') => {
      ignore(self.advance())
      Ok(self.token(Question, start, line, column))
    }
    Some('*') => {
      ignore(self.advance())
      Ok(self.token(Star, start, line, column))
    }
    Some('+') => {
      ignore(self.advance())
      Ok(self.token(Plus, start, line, column))
    }
    Some('#') => {
      ignore(self.advance())
      Ok(self.token(Hash, start, line, column))
    }
    Some(value) => {
      ignore(self.advance())
      Err(
        lex_error(
          "unexpected character: " + value.to_string(),
          source_span(start, self.index, line, column),
        ),
      )
    }
  }
}

///|
/// Tokenize CDDL source while enforcing source and token count limits.
pub fn tokenize(
  source : String,
  limits? : CddlLimits = cddl_limits(),
) -> Result[Array[Token], CddlError] {
  let chars = source.to_array()
  if @utf8.encode(source[:]).length() > limits.max_source_bytes() {
    return Err(
      cddl_error(ResourceLimit, "CDDL source exceeds max_source_bytes"),
    )
  }
  let lexer : Lexer = { chars, limits, index: 0, line: 1, column: 1 }
  let output : Array[Token] = []
  while true {
    if output.length() >= lexer.limits.max_tokens() {
      return Err(cddl_error(ResourceLimit, "CDDL source exceeds max_tokens"))
    }
    let token = match lexer.next_token() {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let at_end = token.kind() == EndOfInput
    output.push(token)
    if at_end {
      return Ok(output)
    }
  } nobreak {
    Ok(output)
  }
}
