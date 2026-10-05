"""Compare the old proximity curve with current settings using actual collisions.

python tools/weapon_pressure.py [--godot PATH]
Both conditions use current enemy HP and weapon levels; only proximity differs.
"""
import argparse
import concurrent.futures
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=shutil.which('godot'))
    args = parser.parse_args()
    if not args.godot:
        parser.error('Godot not found; pass --godot PATH')
    engine = str(Path(args.godot).resolve())
    output_dir = ROOT / 'build' / 'validation'
    output_dir.mkdir(parents=True, exist_ok=True)

    def run(baseline):
        flags = ['--baseline-proximity'] if baseline else ['--after']
        result = subprocess.run([engine, '--headless', '--path', str(ROOT), '--audio-driver', 'Dummy',
                                 '--script', 'tests/weapon_pressure_probe.gd', '--fixed-fps', '60', '--', *flags],
                                cwd=ROOT, capture_output=True, encoding='utf-8', errors='replace', timeout=240)
        log = result.stdout + result.stderr
        (output_dir / ('weapon_pressure_baseline.log' if baseline else 'weapon_pressure_final.log')).write_text(log, encoding='utf-8')
        if result.returncode or re.search(r'SCRIPT ERROR|ERROR:|WARNING:', log):
            raise RuntimeError(log)
        rows = next((json.loads(line) for line in result.stdout.splitlines() if line.startswith('[')), None)
        if rows is None or len(rows) != 36:
            raise RuntimeError('Expected 36 weapon/range/enemy trials')
        return {(r['enemy'], r['distance'], r['weapon'], r['power']): r for r in rows}

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        before, after = list(pool.map(run, [True, False]))
    failures = []
    for key, row in after.items():
        old = before[key]
        if key[1] == 900 and (row['defeated'] != old['defeated'] or abs(row['trial_seconds'] - old['trial_seconds']) > 0.02):
            failures.append(f'Long-range damage changed: {key}')
        if key[1] == 400 and key[3] == 3 and key[0] != 'boss' and row['first_volley_seconds'] < 0:
            failures.append(f'Close LV3 still skips the first attack: {key}')
    for weapon, minimum in [('straight', 11), ('spread', 9)]:
        key = ('boss', 400, weapon, 3)
        row = after[key]
        if not row['defeated'] or row['seconds_to_kill'] < minimum:
            failures.append(f'Close LV3 boss duration outside the target: {weapon}')
        print(f'{weapon} LV3 / 400px boss: {before[key]["seconds_to_kill"]} -> {row["seconds_to_kill"]} seconds')
    if failures:
        raise SystemExit('\n'.join(failures))
    print('Weapon pressure budgets: PASS (stationary, invincible trials; not human difficulty)')


if __name__ == '__main__':
    main()
