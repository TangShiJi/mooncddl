"""Run explicit syntax accept/reject cases; runtime validation is separate."""
import argparse
import json
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--cli', required=True)
parser.add_argument('--report', default='_build/standard-syntax-report.json')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
cases = json.loads((root / 'fixtures/standard-syntax.json').read_text(encoding='utf-8'))
cli = str(Path(args.cli).resolve())
results = []
for case in cases:
    run = subprocess.run([cli, 'check-syntax', case['source']], capture_output=True, timeout=20)
    expected = 0 if case['syntax_valid'] else 2
    results.append({**case, 'expected_exit': expected, 'actual_exit': run.returncode,
                    'passed': run.returncode == expected})
report = {'standard': 'RFC 8610 Appendix B/C', 'cases': len(results),
          'failures': sum(not row['passed'] for row in results), 'results': results}
path = Path(args.report)
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps({k:v for k,v in report.items() if k!='results'}))
raise SystemExit(bool(report['failures']))
