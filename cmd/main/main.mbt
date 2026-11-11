///|
fn print_usage() -> Unit {
  println("MoonCDDL 0.1.0")
  println("Usage:")
  println("  mooncddl validate-json <schema> <json> [root]")
  println("  mooncddl format <schema>")
  println("  mooncddl example <schema> [root]")
}

///|
fn print_error(prefix : String, message : String) -> Unit {
  println(prefix + ": " + message)
}

///|
fn run_validate(
  schema_source : String,
  json_source : String,
  root : String?,
) -> Unit {
  let document = match @cddl.parse_cddl(schema_source) {
    Ok(value) => value
    Err(error) => {
      print_error("schema error", error.message())
      return
    }
  }
  let report = match @cddl.validate_json(document, json_source, root~) {
    Ok(value) => value
    Err(error) => {
      print_error("input error", error.message())
      return
    }
  }
  if report.is_valid() {
    println("valid")
  } else {
    println("invalid (" + report.issues().length().to_string() + " issue(s))")
    for issue in report.issues() {
      let path = if issue.path() == "" { "/" } else { issue.path() }
      println(path + ": " + issue.message())
    }
    if report.truncated() {
      println("additional issues were truncated by max_issues")
    }
  }
}

///|
fn run_format(schema_source : String) -> Unit {
  let document = match @cddl.parse_cddl(schema_source) {
    Ok(value) => value
    Err(error) => {
      print_error("schema error", error.message())
      return
    }
  }
  match @cddl.format_cddl(document) {
    Ok(value) => println(value)
    Err(error) => print_error("format error", error.message())
  }
}

///|
fn run_example(schema_source : String, root : String?) -> Unit {
  let document = match @cddl.parse_cddl(schema_source) {
    Ok(value) => value
    Err(error) => {
      print_error("schema error", error.message())
      return
    }
  }
  match @cddl.generate_example(document, root~) {
    Ok(value) => println(value.describe())
    Err(error) => print_error("generation error", error.message())
  }
}

///|
fn main {
  let args = @env.args()
  if args.length() < 2 {
    print_usage()
    return
  }
  match args[1] {
    "validate-json" if args.length() >= 4 => {
      let root = if args.length() >= 5 { Some(args[4]) } else { None }
      run_validate(args[2], args[3], root)
    }
    "format" if args.length() >= 3 => run_format(args[2])
    "example" if args.length() >= 3 => {
      let root = if args.length() >= 4 { Some(args[3]) } else { None }
      run_example(args[2], root)
    }
    "--version" | "version" => println("MoonCDDL 0.1.0")
    _ => print_usage()
  }
}
