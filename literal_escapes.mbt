///|
fn Lexer::read_unicode_quad(self : Lexer) -> Int32? {
  let mut value = 0
  for _i = 0; _i < 4; _i = _i + 1 {
    match self.advance() {
      Some(c) if is_hex_digit(c) => value = value * 16 + digit_value(c)
      _ => return None
    }
  }
  Some(value)
}

///|
fn Lexer::read_base64_bytes(
  self : Lexer,
  start : Int32,
  line : Int32,
  column : Int32,
) -> Result[Token, CddlError] {
  for _i = 0; _i < 4; _i = _i + 1 {
    ignore(self.advance())
  }
  let chars : Array[Char] = []
  let mut closed = false
  while self.peek() is Some(c) {
    ignore(self.advance())
    if c == '\'' {
      closed = true
      break
    }
    if c == ';' {
      self.skip_comment()
      continue
    }
    if c == ' ' || c == '\t' || c == '\n' || c == '\r' {
      continue
    }
    chars.push(if c == '-' { '+' } else if c == '_' { '/' } else { c })
  }
  if !closed {
    return Err(
      lex_error(
        "unterminated base64 byte string",
        source_span(start, self.index, line, column),
      ),
    )
  }
  if chars.length() % 4 == 1 {
    return Err(
      lex_error(
        "invalid base64 length",
        source_span(start, self.index, line, column),
      ),
    )
  }
  while chars.length() % 4 != 0 {
    chars.push('=')
  }
  let text = chars_to_string(chars)
  try @base64.decode(text[:]) catch {
    _ =>
      Err(
        lex_error(
          "invalid base64 byte string",
          source_span(start, self.index, line, column),
        ),
      )
  } noraise {
    bytes => Ok(self.token(ByteLiteral(bytes), start, line, column))
  }
}
