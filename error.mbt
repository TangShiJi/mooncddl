///|
/// Source range uses zero-based character offsets and one-based line/column values.
#derive(Debug, Eq)
pub struct SourceSpan {
  start : Int32
  end : Int32
  line : Int32
  column : Int32
}

///|
pub fn source_span(
  start : Int32,
  end : Int32,
  line : Int32,
  column : Int32,
) -> SourceSpan {
  { start, end, line, column, }
}

///|
pub fn SourceSpan::start(self : SourceSpan) -> Int32 {
  self.start
}

///|
pub fn SourceSpan::end(self : SourceSpan) -> Int32 {
  self.end
}

///|
pub fn SourceSpan::line(self : SourceSpan) -> Int32 {
  self.line
}

///|
pub fn SourceSpan::column(self : SourceSpan) -> Int32 {
  self.column
}

///|
#derive(Debug, Eq)
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
}

///|
/// Structured parser and schema error. Validation mismatches use
/// `ValidationIssue`, because one value may produce more than one useful issue.
#derive(Debug, Eq)
pub struct CddlError {
  kind : CddlErrorKind
  message : String
  span : SourceSpan?
}

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
  span~ : SourceSpan? = None,
) -> CddlError {
  { kind, message, span, }
}

///|
#derive(Debug, Eq)
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
}

///|
/// One validation mismatch with a stable code and JSON-Pointer-like path.
#derive(Debug, Eq)
pub struct ValidationIssue {
  code : IssueCode
  path : String
  expected : String
  actual : String
  message : String
}

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
  { code, path, expected, actual, message, }
}
