///|
#derive(Debug, Eq)
priv enum XsdClass {
  CodeRange(Int32, Int32)
  ClassUnion(Array[XsdClass])
  ClassNot(XsdClass)
  ClassSubtract(XsdClass, XsdClass)
  Property(String)
  NameStart
  NameChar
}

///|
#derive(Debug, Eq)
priv enum XsdExpr {
  EmptyRegex
  Character(XsdClass)
  RegexSequence(Array[XsdExpr])
  RegexChoice(Array[XsdExpr])
  RegexRepeat(XsdExpr, Int32, Int32?)
}

///|
priv suberror XsdError {
  XsdError(String)
}

///|
priv struct XsdParser {
  chars : Array[Char]
  limits : CddlLimits
  mut index : Int32
}

///|
fn XsdParser::peek(self : XsdParser) -> Char? {
  if self.index < self.chars.length() {
    Some(self.chars[self.index])
  } else {
    None
  }
}

///|
fn XsdParser::take(self : XsdParser, c : Char) -> Bool {
  if self.peek() == Some(c) {
    self.index += 1
    true
  } else {
    false
  }
}

///|
fn XsdParser::require(self : XsdParser, c : Char) -> Unit raise XsdError {
  if !self.take(c) {
    raise XsdError("expected '" + c.to_string() + "' in XSD regular expression")
  }
}

///|
fn XsdParser::escape(self : XsdParser) -> XsdClass raise XsdError {
  let c = match self.peek() {
    Some(c) => c
    None => raise XsdError("trailing regular expression escape")
  }
  self.index += 1
  match c {
    'n' => CodeRange(10, 10)
    'r' => CodeRange(13, 13)
    't' => CodeRange(9, 9)
    'd' => Property("Nd")
    'D' => ClassNot(Property("Nd"))
    's' => ClassUnion([CodeRange(9, 10), CodeRange(13, 13), CodeRange(32, 32)])
    'S' =>
      ClassNot(
        ClassUnion([CodeRange(9, 10), CodeRange(13, 13), CodeRange(32, 32)]),
      )
    'w' => ClassNot(ClassUnion([Property("P"), Property("Z"), Property("C")]))
    'W' => ClassUnion([Property("P"), Property("Z"), Property("C")])
    'i' => NameStart
    'I' => ClassNot(NameStart)
    'c' => NameChar
    'C' => ClassNot(NameChar)
    'p' | 'P' => {
      self.require('{')
      let name : Array[Char] = []
      while self.peek() is Some(c) && c != '}' {
        name.push(c)
        self.index += 1
      }
      self.require('}')
      let property = chars_to_string(name)
      if !unicode_property_known(property) {
        raise XsdError("unknown Unicode property " + property)
      }
      if c == 'p' {
        Property(property)
      } else {
        ClassNot(Property(property))
      }
    }
    '\\'
    | '|'
    | '.'
    | '-'
    | '^'
    | '?'
    | '*'
    | '+'
    | '{'
    | '}'
    | '('
    | ')'
    | '['
    | ']' => CodeRange(c.to_int(), c.to_int())
    _ => raise XsdError("unknown XSD regular expression escape")
  }
}

///|
fn XsdParser::class_char(self : XsdParser) -> XsdClass raise XsdError {
  if self.take('\\') {
    return self.escape()
  }
  match self.peek() {
    Some(c) if c != '[' && c != ']' => {
      self.index += 1
      CodeRange(c.to_int(), c.to_int())
    }
    _ => raise XsdError("expected character class member")
  }
}

///|
fn XsdParser::class(self : XsdParser, depth : Int32) -> XsdClass raise XsdError {
  if depth > self.limits.max_depth() {
    raise XsdError("regular expression class depth limit")
  }
  self.require('[')
  let negative = self.take('^')
  let members : Array[XsdClass] = []
  while self.peek() is Some(c) && c != ']' {
    if c == '-' &&
      self.index + 1 < self.chars.length() &&
      self.chars[self.index + 1] == '[' {
      if members.length() == 0 {
        raise XsdError("subtraction requires a base class")
      }
      self.index += 1
      let subtract = self.class(depth + 1)
      self.require(']')
      let base = ClassUnion(members)
      return ClassSubtract(
        if negative {
          ClassNot(base)
        } else {
          base
        },
        subtract,
      )
    }
    let first = self.class_char()
    if self.peek() == Some('-') &&
      self.index + 1 < self.chars.length() &&
      self.chars[self.index + 1] != ']' &&
      self.chars[self.index + 1] != '[' {
      self.index += 1
      let last = self.class_char()
      match (first, last) {
        (CodeRange(a, _), CodeRange(b, _)) if a <= b =>
          members.push(CodeRange(a, b))
        _ => raise XsdError("invalid character class range")
      }
    } else {
      members.push(first)
    }
  }
  if members.length() == 0 {
    raise XsdError("empty character class")
  }
  self.require(']')
  let body = ClassUnion(members)
  if negative {
    ClassNot(body)
  } else {
    body
  }
}

///|
fn XsdParser::integer(self : XsdParser) -> Int32 raise XsdError {
  let start = self.index
  let mut number = 0
  while self.peek() is Some(c) && is_ascii_digit(c) {
    if number > 100000000 {
      raise XsdError("regular expression quantifier is too large")
    }
    number = number * 10 + digit_value(c)
    self.index += 1
  }
  if self.index == start {
    raise XsdError("expected repetition count")
  }
  number
}

///|
fn XsdParser::atom(self : XsdParser, depth : Int32) -> XsdExpr raise XsdError {
  if depth > self.limits.max_depth() {
    raise XsdError("regular expression depth limit")
  }
  let atom = if self.take('(') {
    let body = self.expression(depth + 1)
    self.require(')')
    body
  } else if self.peek() == Some('[') {
    Character(self.class(depth + 1))
  } else if self.take('.') {
    Character(ClassNot(ClassUnion([CodeRange(10, 10), CodeRange(13, 13)])))
  } else if self.take('\\') {
    Character(self.escape())
  } else {
    match self.peek() {
      Some(c) if !['?', '*', '+', '{', '}', '[', ']', ')', '|'].contains(c) => {
        self.index += 1
        Character(CodeRange(c.to_int(), c.to_int()))
      }
      _ => raise XsdError("expected regular expression atom")
    }
  }
  if self.take('?') {
    RegexRepeat(atom, 0, Some(1))
  } else if self.take('*') {
    RegexRepeat(atom, 0, None)
  } else if self.take('+') {
    RegexRepeat(atom, 1, None)
  } else if self.take('{') {
    let minimum = self.integer()
    let maximum = if self.take(',') {
      if self.peek() == Some('}') {
        None
      } else {
        Some(self.integer())
      }
    } else {
      Some(minimum)
    }
    self.require('}')
    if maximum is Some(n) && n < minimum {
      raise XsdError("reversed repetition bounds")
    }
    RegexRepeat(atom, minimum, maximum)
  } else {
    atom
  }
}

///|
fn XsdParser::expression(
  self : XsdParser,
  depth : Int32,
) -> XsdExpr raise XsdError {
  let choices : Array[XsdExpr] = []
  while true {
    let sequence : Array[XsdExpr] = []
    while self.peek() is Some(c) && c != ')' && c != '|' {
      sequence.push(self.atom(depth + 1))
    }
    choices.push(
      if sequence.length() == 0 {
        EmptyRegex
      } else {
        RegexSequence(sequence)
      },
    )
    if !self.take('|') {
      break
    }
  }
  RegexChoice(choices)
}

///|
fn xsd_class_matches(class : XsdClass, code : Int32) -> Bool {
  match class {
    CodeRange(first, last) => code >= first && code <= last
    ClassUnion(items) => items.any(item => xsd_class_matches(item, code))
    ClassNot(body) => !xsd_class_matches(body, code)
    ClassSubtract(base, subtract) =>
      xsd_class_matches(base, code) && !xsd_class_matches(subtract, code)
    Property(name) => unicode_property_matches(name, code)
    NameStart => xml_name_start(code)
    NameChar =>
      xml_name_start(code) ||
      code == 45 ||
      code == 46 ||
      (code >= 48 && code <= 57) ||
      code == 0xb7 ||
      (code >= 0x300 && code <= 0x36f) ||
      (code >= 0x203f && code <= 0x2040)
  }
}

///|
priv struct XsdMachine {
  input : Array[Char]
  limits : CddlLimits
  mut steps : Int32
}

///|
fn XsdMachine::run(
  self : XsdMachine,
  expression : XsdExpr,
  start : Int32,
  depth : Int32,
) -> Array[Int32] raise XsdError {
  self.steps += 1
  if self.steps > self.limits.max_tokens() || depth > self.limits.max_depth() {
    raise XsdError("regular expression matching resource limit")
  }
  match expression {
    EmptyRegex => [start]
    Character(class) =>
      if start < self.input.length() &&
        xsd_class_matches(class, self.input[start].to_int()) {
        [start + 1]
      } else {
        []
      }
    RegexChoice(choices) => {
      let results : Array[Int32] = []
      for choice in choices {
        for end in self.run(choice, start, depth + 1) {
          if !results.contains(end) {
            results.push(end)
          }
        }
      }
      results
    }
    RegexSequence(items) => {
      let mut states = [start]
      for item in items {
        let next : Array[Int32] = []
        for state in states {
          for end in self.run(item, state, depth + 1) {
            if !next.contains(end) {
              next.push(end)
            }
          }
        }
        states = next
        if states.length() == 0 {
          break
        }
      }
      states
    }
    RegexRepeat(body, minimum, maximum) => {
      let results : Array[Int32] = if minimum == 0 { [start] } else { [] }
      let mut states = [start]
      let cap = maximum
        .unwrap_or(self.input.length() + 1)
        .min(self.input.length() + 1)
      for count = 1; count <= cap; count = count + 1 {
        let next : Array[Int32] = []
        for state in states {
          for end in self.run(body, state, depth + 1) {
            if end == state {
              if !results.contains(end) {
                results.push(end)
              }
            } else if !next.contains(end) {
              next.push(end)
            }
          }
        }
        if count >= minimum {
          for end in next {
            if !results.contains(end) {
              results.push(end)
            }
          }
        }
        states = next
        if states.length() == 0 {
          break
        }
      }
      results
    }
  }
}

///|
/// Match the entire text using XSD regex semantics: ^ and $ are literals,
/// Unicode properties and class subtraction are supported, and '.' excludes
/// CR/LF. Unicode property data is pinned to version 13.0.0.
pub fn match_xsd_regex(
  pattern : String,
  input : String,
  limits~ : CddlLimits = cddl_limits(),
) -> Result[Bool, CddlError] {
  if @utf8.encode(pattern[:]).length() > limits.max_source_bytes() ||
    @utf8.encode(input[:]).length() > limits.max_source_bytes() {
    return Err(cddl_error(ResourceLimit, "XSD regular expression source limit"))
  }
  let parser : XsdParser = { chars: pattern.to_array(), limits, index: 0, }
  try {
    let expression = parser.expression(0)
    if parser.index != parser.chars.length() {
      raise XsdError("trailing XSD regular expression syntax")
    }
    let machine : XsdMachine = { input: input.to_array(), limits, steps: 0, }
    Ok(machine.run(expression, 0, 0).contains(machine.input.length()))
  } catch {
    XsdError(message) => Err(cddl_error(ValidationFailure, message))
  }
}
