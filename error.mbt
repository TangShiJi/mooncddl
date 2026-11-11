///|
/// Source range uses zero-based character offsets and one-based line/column values.
pub struct SourceSpan {
  start : Int
  end : Int
  line : Int
  column : Int
} derive(Debug, Eq)

///|
pub fn source_span(
  start : Int,
  end : Int,
  line : Int,
  column : Int,
) -> SourceSpan {
  { start, end, line, column }
}

///|
pub fn SourceSpan::start(self : SourceSpan) -> Int {
  self.start
}

///|
pub fn SourceSpan::end(self : SourceSpan) -> Int {
  self.end
}

///|
pub fn SourceSpan::line(self : SourceSpan) -> Int {
  self.line
}

///|
pub fn SourceSpan::column(self : SourceSpan) -> Int {
  self.column
}

///|
pub(all) enum CddlErrorKind {
  LexicalError
  SyntaxError
  DuplicateRule
  UnknownRule
  InvalidOccurrence
  InvalidRange
  RecursiveReference
  UnsupportedFeature
  ResourceLimit
  ValidationFailure
  JsonConversion
} derive(Debug, Eq)

///|
/// Structured parser and schema error. Validation mismatches use
/// `ValidationIssue`, because one value may produce more than one useful issue.
pub struct CddlError {
  kind : CddlErrorKind
  message : String
  span : SourceSpan?
} derive(Debug, Eq)

///|
pub fn CddlError::kind(self : CddlError) -> CddlErrorKind {
  self.kind
}

///|
pub fn CddlError::message(self : CddlError) -> String {
  self.message
}

///|
pub fn CddlError::span(self : CddlError) -> SourceSpan? {
  self.span
}

///|
pub fn cddl_error(
  kind : CddlErrorKind,
  message : String,
  span? : SourceSpan? = None,
) -> CddlError {
  { kind, message, span }
}

///|
pub(all) enum IssueCode {
  TypeMismatch
  LiteralMismatch
  OutOfRange
  MissingMember
  UnexpectedMember
  TooFewItems
  TooManyItems
  SizeMismatch
  ComparisonFailed
  UnknownReference
  RecursionLimit
  IssueLimit
} derive(Debug, Eq)

///|
/// One validation mismatch with a stable code and JSON-Pointer-like path.
pub struct ValidationIssue {
  code : IssueCode
  path : String
  expected : String
  actual : String
  message : String
} derive(Debug, Eq)

///|
pub fn ValidationIssue::code(self : ValidationIssue) -> IssueCode {
  self.code
}

///|
pub fn ValidationIssue::path(self : ValidationIssue) -> String {
  self.path
}

///|
pub fn ValidationIssue::expected(self : ValidationIssue) -> String {
  self.expected
}

///|
pub fn ValidationIssue::actual(self : ValidationIssue) -> String {
  self.actual
}

///|
pub fn ValidationIssue::message(self : ValidationIssue) -> String {
  self.message
}

///|
pub fn validation_issue(
  code : IssueCode,
  path : String,
  expected : String,
  actual : String,
  message : String,
) -> ValidationIssue {
  { code, path, expected, actual, message }
}
