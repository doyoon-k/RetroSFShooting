"""Validate the M1 lure/cross/core rotation and input-only collision routes.

python tools/siege_cycles.py
Isolates M1; does not establish human difficulty or whole-stage survival.
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
         '--audio-driver', 'Dummy', '--script', 'tests/siege_cycle_probe.gd', '--fixed-fps', '60'],
        cwd=ROOT, capture_output=True, encoding='utf-8', errors='replace', timeout=120)
    log = result.stdout + result.stderr
    directory = ROOT / 'build/validation'
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / 'siege_cycles.log'
    path.write_text(log, encoding='utf-8')
    report = next((json.loads(line) for line in result.stdout.splitlines() if line.startswith('{')), None)
    if result.returncode or re.search(r'SCRIPT ERROR|ERROR:|WARNING:', log) or report is None:
        raise SystemExit(f'Siege probe failed; see {path}\n{result.stderr[:2000]}')
    if report['failures'] or len(report['trials']) != 24:
        raise SystemExit(f'Siege cycle failures; see {path}')
    print('Siege cycles: 24/24 no-hit; lure → cross → core → bank charge; legacy 2-second recovery verified')
    print('P2, 460px/s; real collisions; no shooting, bombs or invincibility')


if __name__ == '__main__':
    main()
