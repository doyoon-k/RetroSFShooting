"""Compare the initial and stronger bank shot; validate real P2 movement routes.

python tools/ricochet_pressure.py
Isolated attack diagnostics, not human difficulty or whole-stage validation.
"""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=shutil.which('godot'))
    options = parser.parse_args()
    if not options.godot:
        parser.error('Godot executable not found; pass --godot PATH')
    result = subprocess.run(
        [str(Path(options.godot).resolve()), '--headless', '--path', str(ROOT),
         '--audio-driver', 'Dummy', '--script', 'tests/ricochet_pressure_probe.gd', '--fixed-fps', '60'],
        cwd=ROOT, capture_output=True, encoding='utf-8', errors='replace', timeout=90)
    output = result.stdout + result.stderr
    directory = ROOT / 'build' / 'validation'
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / 'ricochet_pressure.log'
    path.write_text(output, encoding='utf-8')
    report = next((json.loads(line) for line in result.stdout.splitlines() if line.startswith('{')), None)
    if result.returncode or re.search(r'SCRIPT ERROR|ERROR:|WARNING:', output) or report is None or report['failures']:
        raise SystemExit(f'Bank pressure probe failed; see {path}\n{output[-3000:]}')
    print(f"Stationary contacts: {report['old_contacts']} -> {report['new_contacts']}; "
          f"safe samples: {report['old_safe_samples']}/9 -> {report['new_safe_samples']}/9")
    print(f"Known-cue P2 movement: {report['moving_no_hit']}/12 no-hit; all six center-column routes pass")
    print('Isolated bank attack; contact pressure is not a human difficulty score')


if __name__ == '__main__':
    main()
