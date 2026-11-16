"""Run the published RFC behavior corpus against MoonCDDL and a reference CLI.

Requires the independently installed anweiss/cddl 0.10.7 executable when
--reference is given. It is a test oracle, not a project runtime dependency.
"""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument("--cli", required=True)
parser.add_argument("--reference")
parser.add_argument("--report", default="_build/differential.json")
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
cli = str(Path(args.cli).resolve())
reference = str(Path(args.reference).resolve()) if args.reference else None
cases = json.loads((root / "fixtures/rfc8610.json").read_text(encoding="utf-8"))
results = []
with tempfile.TemporaryDirectory(prefix="mooncddl-reference-") as directory:
    schema_path = Path(directory) / "schema.cddl"
    json_path = Path(directory) / "value.json"
    for case in cases:
        text = json.dumps(case["json"], ensure_ascii=False, separators=(",", ":"))
        own = subprocess.run([cli, "validate-json", case["schema"], text], capture_output=True, timeout=20)
        result = {"id": case["id"], "section": case["section"], "expected": case["valid"],
                  "actual": own.returncode == 0, "exit_code": own.returncode}
        if reference:
            schema_path.write_text(case["schema"] + "\n", encoding="utf-8")
            json_path.write_text(text, encoding="utf-8")
            oracle = subprocess.run([reference, "--ci", "validate", "--cddl", str(schema_path), "--json", str(json_path)], capture_output=True, timeout=20)
            result["reference"] = oracle.returncode == 0
            result["reference_expected"] = case.get("reference_valid", case["valid"])
            if "reference_difference" in case:
                result["documented_difference"] = case["reference_difference"]
            if result["reference"] != case["valid"]:
                result["reference_output"] = (oracle.stdout + oracle.stderr).decode("utf-8", errors="replace")[:2000]
        results.append(result)
failed = [r for r in results if r["actual"] != r["expected"] or ("reference" in r and r["reference"] != r["reference_expected"])]
report = {"reference": "anweiss/cddl 0.10.7" if reference else None,
          "cases": len(results), "failures": len(failed),
          "documented_reference_differences": sum(r.get("reference") != r["expected"] for r in results) if reference else None,
          "results": results}
path = Path(args.report)
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"cases": len(results), "failures": len(failed), "failed_ids": [r["id"] for r in failed]}))
raise SystemExit(bool(failed))
