///|
/// Explicit limits keep schemas and untrusted values from causing unbounded
/// recursion, diagnostics, or container scans.
pub struct CddlLimits {
  max_source_bytes : Int
  max_tokens : Int
  max_rules : Int
  max_depth : Int
  max_container_items : Int
  max_issues : Int
} derive(Debug, Eq)

///|
pub fn cddl_limits(
  max_source_bytes? : Int = 1024 * 1024,
  max_tokens? : Int = 100000,
  max_rules? : Int = 10000,
  max_depth? : Int = 128,
  max_container_items? : Int = 100000,
  max_issues? : Int = 100,
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
fn positive_limit(value : Int) -> Int {
  if value < 1 {
    1
  } else {
    value
  }
}

///|
pub fn CddlLimits::max_source_bytes(self : CddlLimits) -> Int {
  self.max_source_bytes
}

///|
pub fn CddlLimits::max_tokens(self : CddlLimits) -> Int {
  self.max_tokens
}

///|
pub fn CddlLimits::max_rules(self : CddlLimits) -> Int {
  self.max_rules
}

///|
pub fn CddlLimits::max_depth(self : CddlLimits) -> Int {
  self.max_depth
}

///|
pub fn CddlLimits::max_container_items(self : CddlLimits) -> Int {
  self.max_container_items
}

///|
pub fn CddlLimits::max_issues(self : CddlLimits) -> Int {
  self.max_issues
}
