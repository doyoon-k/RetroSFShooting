"""Validate a complete stage kill route at the slowest ship's real movement speed.

python tools/clear_route.py [--compare]
Invincible, no bombs, natural pickups: validates damage opportunities, not dodging.
The previous HP comparison is diagnostic and is not required to clear every enemy.
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
    parser.add_argument('--compare', action='store_true')
    options = parser.parse_args()
    if not options.godot:
        parser.error('Godot executable not found; pass --godot PATH')
    engine = str(Path(options.godot).resolve())
    output = ROOT / 'build/validation'
    output.mkdir(parents=True, exist_ok=True)
    for baseline in ([True, False] if options.compare else [False]):
        command = [engine, '--headless', '--path', str(ROOT), '--audio-driver', 'Dummy',
                   '--script', 'tests/stage_clear_route_probe.gd', '--fixed-fps', '60']
        if baseline:
            command += ['--', '--baseline']
        result = subprocess.run(command, cwd=ROOT, capture_output=True, encoding='utf-8',
                                errors='replace', timeout=180)
        log = result.stdout + result.stderr
        name = 'baseline' if baseline else 'after'
        (output / f'clear_route_{name}.log').write_text(log, encoding='utf-8')
        if result.returncode or re.search(r'SCRIPT ERROR|ERROR:|WARNING:', log):
            raise SystemExit(log)
        report = next((json.loads(line) for line in result.stdout.splitlines()
                       if line.startswith('{')), None)
        if report is None:
            raise SystemExit('Clear route probe produced no report')
        print(f'{name}: {report["defeated"]}/{report["expected_spawned"]} killed, '
              f'clear={report["clear"]}, seconds={report["seconds"]}', flush=True)
        if not report['clear'] or report['spawned'] != report['expected_spawned']:
            raise SystemExit('Route did not encounter the complete authored stage')
        counted_kills = sum(row['killed'] for row in report['by_enemy'].values())
        if counted_kills != report['defeated']:
            raise SystemExit('Kill signal accounting disagrees with the stage counter')
        if not baseline and (report['missed'] or counted_kills != report['expected_spawned']):
            raise SystemExit(f'Full-clear route missed enemies: {report["missed"]}')
    print('Full-clear damage opportunities: PASS (invincible; not survival validation)')


if __name__ == '__main__':
    main()
