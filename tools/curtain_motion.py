"""Validate P2 input-only, no-hit routes through the two curtain bursts.

python tools/curtain_motion.py
Uses real Godot collisions; isolates curtains, not the complete boss encounter.
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
    engine = str(Path(options.godot).resolve())
    result = subprocess.run([engine, '--headless', '--path', str(ROOT), '--audio-driver', 'Dummy',
                             '--script', 'tests/curtain_motion_probe.gd', '--fixed-fps', '60'],
                            cwd=ROOT, capture_output=True, encoding='utf-8', errors='replace', timeout=120)
    log = result.stdout + result.stderr
    directory = ROOT / 'build/validation'
    directory.mkdir(parents=True, exist_ok=True)
    (directory / 'curtain_motion.log').write_text(log, encoding='utf-8')
    if result.returncode or re.search(r'SCRIPT ERROR|ERROR:|WARNING:', log):
        raise SystemExit(f'Curtain engine exit={result.returncode}; see {directory / "curtain_motion.log"}\n{result.stderr[:2000]}')
    report = next((json.loads(line) for line in result.stdout.splitlines() if line.startswith('{')), None)
    if report is None or len(report['trials']) != 208:
        raise SystemExit('Curtain probe did not run every trial')
    failures = [trial for trial in report['trials'] if trial['hits'] or trial['move_speed'] != 460
                or trial['walls_crossed'] != trial['expected_walls']
                or trial['fired_walls'] != trial['expected_walls']
                or trial['selected_routes'] != trial['expected_routes']]
    if failures:
        raise SystemExit(f'Curtain route failures: {failures}')
    print('Curtain routes: 208/208 no-hit (P2, 460px/s; all four routes and consecutive pairs)')


if __name__ == '__main__':
    main()
