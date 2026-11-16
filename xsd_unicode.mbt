///|
fn unicode_category(code : Int32) -> String {
  let mut low = 0
  let mut high = unicode_categories.length() - 1
  while low <= high {
    let middle = low + (high - low) / 2
    let (first, last, category) = unicode_categories[middle]
    if code < first {
      high = middle - 1
    } else if code > last {
      low = middle + 1
    } else {
      return category
    }
  }
  "Cn"
}

///|
fn unicode_property_known(name : String) -> Bool {
  if name.has_prefix("Is") {
    let block = name[2:].to_owned()
    return unicode_blocks.any(item => item.0 == block)
  }
  [
    "L", "M", "N", "P", "Z", "S", "C", "Lu", "Ll", "Lt", "Lm", "Lo", "Mn", "Mc",
    "Me", "Nd", "Nl", "No", "Pc", "Pd", "Ps", "Pe", "Pi", "Pf", "Po", "Zs", "Zl",
    "Zp", "Sm", "Sc", "Sk", "So", "Cc", "Cf", "Co", "Cs", "Cn",
  ].contains(name)
}

///|
fn unicode_property_matches(name : String, code : Int32) -> Bool {
  if name.has_prefix("Is") {
    let block = name[2:].to_owned()
    return unicode_blocks.any(item => {
      item.0 == block && code >= item.1 && code <= item.2
    })
  }
  let category = unicode_category(code)
  category == name || (name.length() == 1 && category.has_prefix(name))
}

///|
fn xml_name_start(code : Int32) -> Bool {
  code == 58 ||
  code == 95 ||
  (code >= 65 && code <= 90) ||
  (code >= 97 && code <= 122) ||
  (code >= 0xc0 && code <= 0xd6) ||
  (code >= 0xd8 && code <= 0xf6) ||
  (code >= 0xf8 && code <= 0x2ff) ||
  (code >= 0x370 && code <= 0x37d) ||
  (code >= 0x37f && code <= 0x1fff) ||
  (code >= 0x200c && code <= 0x200d) ||
  (code >= 0x2070 && code <= 0x218f) ||
  (code >= 0x2c00 && code <= 0x2fef) ||
  (code >= 0x3001 && code <= 0xd7ff) ||
  (code >= 0xf900 && code <= 0xfdcf) ||
  (code >= 0xfdf0 && code <= 0xfffd) ||
  (code >= 0x10000 && code <= 0xeffff)
}
