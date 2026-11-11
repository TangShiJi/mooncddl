///|
/// Explicit limits keep schemas and untrusted values from causing unbounded
/// recursion, diagnostics, or container scans.
#derive(Debug, Eq)
pub struct CddlLimits {
  max_source_bytes : Int32
  max_tokens : Int32
  max_rules : Int32
  max_depth : Int32
  max_container_items : Int32
  max_issues : Int32
}

///|
pub fn cddl_limits(
  max_source_bytes~ : Int32 = 1024 * 1024,
  max_tokens~ : Int32 = 100000,
  max_rules~ : Int32 = 10000,
  max_depth~ : Int32 = 128,
  max_container_items~ : Int32 = 100000,
  max_issues~ : Int32 = 100,
) -> CddlLimits {
  {
    max_source_bytes: positive_limit(max_source_bytes),
    max_tokens: positive_limit(max_tokens),
    max_rules: positive_limit(max_rules),
    max_depth: positive_limit(max_depth),
    max_container_items: positive_limit(max_container_items),
    max_issues: positive_limit(max_issues),
  }
}

///|
fn positive_limit(value : Int32) -> Int32 {
  if value < 1 {
    1
  } else {
    value
  }
}

///|
pub fn CddlLimits::max_source_bytes(self : CddlLimits) -> Int32 {
  self.max_source_bytes
}

///|
pub fn CddlLimits::max_tokens(self : CddlLimits) -> Int32 {
  self.max_tokens
}

///|
pub fn CddlLimits::max_rules(self : CddlLimits) -> Int32 {
  self.max_rules
}

///|
pub fn CddlLimits::max_depth(self : CddlLimits) -> Int32 {
  self.max_depth
}

///|
pub fn CddlLimits::max_container_items(self : CddlLimits) -> Int32 {
  self.max_container_items
}

///|
pub fn CddlLimits::max_issues(self : CddlLimits) -> Int32 {
  self.max_issues
}
