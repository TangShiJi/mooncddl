"""Compare .regexp behavior to the independently implemented libxml2 XSD engine.

Install the test-only dependency with: python -m pip install lxml==6.0.2
"""
import argparse
import json
from pathlib import Path
import subprocess
from lxml import etree

parser = argparse.ArgumentParser()
parser.add_argument("--cli", required=True)
parser.add_argument("--report", default="_build/xsd-differential.json")
args = parser.parse_args()
cli = str(Path(args.cli).resolve())
cases = [
    ("[a-z]+", "abc"), ("[a-z]+", "x1"), ("^a$", "a"), ("^a$", "^a$"),
    ("a.b", "a\nb"), ("a.b", "a\rb"), ("a.b", "axb"),
    ("a(b|c){2,3}", "abcb"), ("a(b|c){2,3}", "ab"),
    ("(a?){3}", "a"), ("(a?)*", ""), ("a{2,}", "aaaa"), ("a{2}", "aa"),
    ("[a-z-[aeiou]]+", "bcdf"), ("[a-z-[aeiou]]+", "bad"),
    ("[^a-z-[0-9]]+", "!?"), ("[^a-z-[0-9]]+", "9"),
    (r"\p{L}+", "中文é"), (r"\p{L}+", "123"), (r"\d+", "١٢٣"),
    (r"\D+", "abc"), (r"\p{IsBasicLatin}+", "abc"), (r"\p{IsBasicLatin}+", "中文"),
    (r"\i\c*", "名:字-1"), (r"\i\c*", "1name"), (r"\w+", "符号+"),
    (r"\s+", " \t\n\r"), ("[A-Z-[D-F]]", "E"), ("[A-Z-[D-F]]", "A"),
    ("[a-z-[d-f-[e]]]", "e"), ("[a-z-[d-f-[e]]]", "d"),
    (r"\p{Lu}+", "ABC"), (r"\p{Ll}+", "é"), (r"\P{N}+", "名字"),
]
results = []
namespace = "{http://www.w3.org/2001/XMLSchema}"
for pattern, text in cases:
    schema = etree.Element(namespace + "schema", nsmap={"xs": namespace[1:-1]})
    element = etree.SubElement(schema, namespace + "element", name="v")
    restriction = etree.SubElement(etree.SubElement(element, namespace + "simpleType"), namespace + "restriction", base="xs:string")
    etree.SubElement(restriction, namespace + "pattern", value=pattern)
    checker = etree.XMLSchema(schema)
    value = etree.Element("v")
    value.text = text
    expected = checker.validate(value)
    source = "root = tstr .regexp " + json.dumps(pattern, ensure_ascii=False)
    own = subprocess.run([cli, "validate-json", source, json.dumps(text, ensure_ascii=False)], capture_output=True, timeout=20)
    results.append({"pattern": pattern, "text": text, "libxml2": expected, "mooncddl": own.returncode == 0})
# These cases have direct language/set-theoretic answers in XSD Part 2,
# Appendix F. libxml2 versions differ here; retain every discrepancy in the
# report rather than treating one implementation as the normative standard.
normative = {
    ("(a?){3}", "a"): True,
    (r"\p{L}+", "中文é"): True,
    ("[a-z-[d-f-[e]]]", "e"): True,
}
for result in results:
    result["expected"] = normative.get((result["pattern"], result["text"]), result["libxml2"])
    if (result["pattern"], result["text"]) in normative:
        result["basis"] = "XSD Part 2 Appendix F: repetition, Letter category, recursive set subtraction"
failed = [r for r in results if r["expected"] != r["mooncddl"]]
report = {"oracle": "libxml2 XSD", "libxml_version": list(etree.LIBXML_VERSION),
          "lxml_version": list(etree.LXML_VERSION), "cases": len(results), "failures": len(failed),
          "reference_differences": sum(r["libxml2"] != r["mooncddl"] for r in results), "results": results}
path = Path(args.report)
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"cases": len(results), "failures": len(failed), "failed": failed}, ensure_ascii=False))
raise SystemExit(bool(failed))
