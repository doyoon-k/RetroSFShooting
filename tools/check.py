"""Import and test with Godot. No Python packages required.

python tools/check.py [--godot PATH] [--screenshots]
Uses the GUI executable directly because some Windows console shims fail.
"""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--godot', default=shutil.which('godot') or shutil.which('godot.exe'))
parser.add_argument('--screenshots', action='store_true')
args = parser.parse_args()
if not args.godot:
    parser.error('Godot executable not found; pass --godot PATH.')
engine = str(Path(args.godot).resolve())
log_dir = ROOT / 'build' / 'validation'
log_dir.mkdir(parents=True, exist_ok=True)
commands = [
    ('import', ['--headless', '--editor', '--import']),
    ('sfx', ['--headless', '--audio-driver', 'Dummy', '--script', 'tests/sfx_probe.gd', '--fixed-fps', '60']),
    ('title', (['--rendering-method', 'gl_compatibility'] if args.screenshots else ['--headless'])
     + ['--audio-driver', 'Dummy', '--script', 'tests/title_probe.gd', '--fixed-fps', '60']
     + (['--', '--screenshots'] if args.screenshots else [])),
    ('title_exit', ['--headless', '--audio-driver', 'Dummy', '--script', 'tests/title_probe.gd', '--fixed-fps', '60', '--', '--exit-test']),
    ('pilot_select', (['--rendering-method', 'gl_compatibility'] if args.screenshots else ['--headless'])
     + ['--audio-driver', 'Dummy', '--script', 'tests/pilot_select_probe.gd', '--fixed-fps', '60']
     + (['--', '--screenshots'] if args.screenshots else [])),
    ('tests', (['--rendering-method', 'gl_compatibility'] if args.screenshots else ['--headless'])
     + ['--audio-driver', 'Dummy', '--script', 'tests/run_tests.gd', '--fixed-fps', '60']
     + (['--', '--screenshots'] if args.screenshots else [])),
    ('ricochet', (['--rendering-method', 'gl_compatibility'] if args.screenshots else ['--headless'])
     + ['--audio-driver', 'Dummy', '--script', 'tests/ricochet_probe.gd', '--fixed-fps', '60']
     + (['--', '--screenshots'] if args.screenshots else [])),
]
for name, command in commands:
    result = subprocess.run([engine, '--path', str(ROOT), *command], cwd=ROOT,
                            capture_output=True, encoding='utf-8', errors='replace', timeout=120)
    output = result.stdout + result.stderr
    (log_dir / f'{name}.log').write_text(output, encoding='utf-8')
    if result.returncode or re.search(r'(SCRIPT ERROR|ERROR:|WARNING:)', output):
        print(output)
        sys.exit(result.returncode or 1)
    print(f'{name}: OK')
    for line in output.splitlines():
        if line.startswith(('SFX:', 'TEST RESULT:', 'PILOT SELECT:', 'TITLE:', 'TITLE EXIT:')):
            print(line)
        elif name == 'ricochet' and line.startswith('{'):
            report = json.loads(line)
            print(f"Bank shot: {report['checks']} checks, {len(report['failures'])} failures")
print(f'Logs: {log_dir}')
