///|
/// Predefined CDDL data types supported by the validator.
#derive(Debug, Eq)
pub(all) enum PrimitiveType {
  AnyType
  BoolType
  NilType
  UintType
  NintType
  IntType
  FloatType
  NumberType
  TextType
  BytesType
  ArrayTypeName
  MapTypeName
}

///|
/// Implemented RFC 8610 control operators. Unsupported controls are rejected
/// during parsing instead of being silently ignored.
#derive(Debug, Eq)
pub(all) enum ControlOperator {
  SizeControl
  LessThanControl
  LessOrEqualControl
  GreaterThanControl
  GreaterOrEqualControl
  EqualControl
  NotEqualControl
  AndControl
  WithinControl
  BitsControl
  DefaultControl
  TagContentControl
  CborControl
  CborSequenceControl
  RegexpControl
}

///|
/// Cardinality attached to a group entry. `max = None` represents an
/// unbounded upper limit.
#derive(Debug, Eq)
pub struct Occurrence {
  min : Int32
  max : Int32?
}

///|
pub fn occurrence(min : Int32, max : Int32?) -> Occurrence {
  { min, max, }
}

///|
pub fn once() -> Occurrence {
  { min: 1, max: Some(1), }
}

///|
pub fn optional() -> Occurrence {
  { min: 0, max: Some(1), }
}

///|
pub fn zero_or_more() -> Occurrence {
  { min: 0, max: None, }
}

///|
pub fn one_or_more() -> Occurrence {
  { min: 1, max: None, }
}

///|
pub fn Occurrence::min(self : Occurrence) -> Int32 {
  self.min
}

///|
pub fn Occurrence::max(self : Occurrence) -> Int32? {
  self.max
}

///|
/// Parsed type expression. Group containers hold entries so the parser keeps
/// cardinality and map-key semantics rather than flattening them away.
#derive(Debug, Eq)
pub(all) enum TypeExpr {
  Primitive(PrimitiveType)
  Literal(CddlValue)
  Reference(String)
  Choice(Array[TypeExpr])
  IntegerRange(Int64, Int64, Bool)
  ArraySchema(Array[GroupEntry])
  MapSchema(Array[GroupEntry])
  TaggedSchema(Int64, TypeExpr)
  Controlled(TypeExpr, ControlOperator, TypeExpr)
  GroupSchema(Array[Array[GroupEntry]])
  Application(String, Array[TypeExpr])
  Unwrap(TypeExpr)
  Enumeration(TypeExpr)
  MajorSchema(Int32, UInt64?)
  ValueRange(CddlValue, CddlValue, Bool)
  DynamicRange(TypeExpr, TypeExpr, Bool)
}

///|
pub fn primitive(kind : PrimitiveType) -> TypeExpr {
  Primitive(kind)
}

///|
pub fn literal(value : CddlValue) -> TypeExpr {
  Literal(value)
}

///|
pub fn reference(name : String) -> TypeExpr {
  Reference(name)
}

///|
pub fn choice(alternatives : Array[TypeExpr]) -> TypeExpr {
  Choice(alternatives.copy())
}

///|
pub fn integer_range(
  lower : Int64,
  upper : Int64,
  upper_exclusive : Bool,
) -> TypeExpr {
  IntegerRange(lower, upper, upper_exclusive)
}

///|
pub fn array_schema(entries : Array[GroupEntry]) -> TypeExpr {
  ArraySchema(entries.copy())
}

///|
pub fn map_schema(entries : Array[GroupEntry]) -> TypeExpr {
  MapSchema(entries.copy())
}

///|
pub fn tagged_schema(tag : Int64, value : TypeExpr) -> TypeExpr {
  TaggedSchema(tag, value)
}

///|
pub fn controlled(
  target : TypeExpr,
  operator : ControlOperator,
  argument : TypeExpr,
) -> TypeExpr {
  Controlled(target, operator, argument)
}

///|
/// One array item or map member declaration. A missing key means an array
/// item; a present key means a map entry.
#derive(Debug, Eq)
pub struct GroupEntry {
  key : TypeExpr?
  value : TypeExpr
  occurrence : Occurrence
  cut : Bool
}

///|
pub fn group_entry(
  value : TypeExpr,
  key~ : TypeExpr? = None,
  occurrence~ : Occurrence = once(),
  cut~ : Bool = false,
) -> GroupEntry {
  { key, value, occurrence, cut, }
}

///|
pub fn GroupEntry::is_cut(self : GroupEntry) -> Bool {
  self.cut
}

///|
pub fn GroupEntry::key(self : GroupEntry) -> TypeExpr? {
  self.key
}

///|
pub fn GroupEntry::value(self : GroupEntry) -> TypeExpr {
  self.value
}

///|
pub fn GroupEntry::occurrence(self : GroupEntry) -> Occurrence {
  self.occurrence
}

///|
#derive(Debug, Eq)
pub struct Rule {
  name : String
  value : TypeExpr
  span : SourceSpan
  parameters : Array[String]
}

///|
pub fn rule(
  name : String,
  value : TypeExpr,
  span : SourceSpan,
  parameters~ : Array[String] = [],
) -> Rule {
  { name, value, span, parameters, }
}

///|
pub fn Rule::parameters(self : Rule) -> Array[String] {
  self.parameters.copy()
}

///|
pub fn Rule::name(self : Rule) -> String {
  self.name
}

///|
pub fn Rule::value(self : Rule) -> TypeExpr {
  self.value
}

///|
pub fn Rule::span(self : Rule) -> SourceSpan {
  self.span
}

///|
/// Immutable parsed schema. The first declared rule is the default entry
/// point, matching common CDDL tooling behavior.
#derive(Debug, Eq)
pub struct Schema {
  rules : Array[Rule]
}

///|
pub fn schema(rules : Array[Rule]) -> Schema {
  { rules: rules.copy(), }
}

///|
pub fn Schema::rules(self : Schema) -> Array[Rule] {
  self.rules.copy()
}

///|
pub fn Schema::root_name(self : Schema) -> String? {
  if self.rules.length() == 0 {
    None
  } else {
    Some(self.rules[0].name())
  }
}

///|
pub fn Schema::lookup(self : Schema, name : String) -> TypeExpr? {
  for item in self.rules {
    if item.name() == name {
      return Some(item.value())
    }
  }
  if name.has_prefix("$$") {
    Some(GroupSchema([[]]))
  } else if name.has_prefix("$") {
    Some(Choice([]))
  } else {
    prelude_expression(name)
  }
}

///|
pub fn primitive_from_name(name : String) -> PrimitiveType? {
  match name {
    "any" => Some(AnyType)
    "bool" => Some(BoolType)
    "nil" | "null" => Some(NilType)
    "uint" => Some(UintType)
    "nint" => Some(NintType)
    "int" => Some(IntType)
    "float" | "float16" | "float32" | "float64" => Some(FloatType)
    "number" => Some(NumberType)
    "tstr" | "text" => Some(TextType)
    "bstr" | "bytes" => Some(BytesType)
    "array" => Some(ArrayTypeName)
    "map" => Some(MapTypeName)
    _ => None
  }
}

///|
pub fn control_from_name(name : String) -> ControlOperator? {
  match name {
    "size" => Some(SizeControl)
    "lt" => Some(LessThanControl)
    "le" => Some(LessOrEqualControl)
    "gt" => Some(GreaterThanControl)
    "ge" => Some(GreaterOrEqualControl)
    "eq" => Some(EqualControl)
    "ne" => Some(NotEqualControl)
    "and" => Some(AndControl)
    "within" => Some(WithinControl)
    "bits" => Some(BitsControl)
    "default" => Some(DefaultControl)
    "cbor" => Some(CborControl)
    "cborseq" => Some(CborSequenceControl)
    "regexp" => Some(RegexpControl)
    _ => None
  }
}
