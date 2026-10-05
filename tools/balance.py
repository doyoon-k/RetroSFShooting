"""Reproducible normal-speed balance trials; no packages required.

python tools/balance.py [--screenshots]
Actual-damage reactive trials are diagnostics, not human difficulty proofs.
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
    parser.add_argument('--screenshots', action='store_true')
    parser.add_argument('--boss-patterns', action='store_true', help='Also test 25 stationary positions across major encounters')
    options = parser.parse_args()
    if not options.godot:
        parser.error('Godot executable not found; pass --godot PATH')
    engine = str(Path(options.godot).resolve())
    log_dir = ROOT / 'build' / 'validation'
    log_dir.mkdir(parents=True, exist_ok=True)
    jobs = [
        ('aim_lv1', 'stage_balance_probe', ['--power1']),
        ('aim_lv3', 'stage_balance_probe', ['--power3']),
        ('slow_reactive', 'stage_survival_probe', ['--pilot=P2', '--weapon=mixed']),
        ('weak_no_bombs', 'stage_survival_probe', ['--pilot=P2', '--weapon=straight', '--power1', '--no-bombs']),
        ('recovery', 'stage_survival_probe', ['--pilot=P2', '--weapon=mixed', '--recovery']),
        ('fast_aggressive', 'stage_survival_probe', ['--pilot=P5', '--weapon=mixed', '--power3', '--aggressive']),
    ]

    def run(job):
        name, script, flags = job
        render = options.screenshots and name == 'slow_reactive'
        command = [engine, '--path', str(ROOT), *(['--rendering-method', 'gl_compatibility'] if render else ['--headless']),
                   '--audio-driver', 'Dummy', '--script', f'tests/{script}.gd', '--fixed-fps', '60', '--', *flags,
                   *(['--screenshots'] if render else [])]
        result = subprocess.run(command, cwd=ROOT, capture_output=True, encoding='utf-8', errors='replace', timeout=240)
        output = result.stdout + result.stderr
        (log_dir / f'balance_{name}.log').write_text(output, encoding='utf-8')
        if result.returncode or re.search(r'SCRIPT ERROR|ERROR:|WARNING:', output):
            raise RuntimeError(f'{name}: {output}')
        report = next((json.loads(line) for line in output.splitlines() if line.startswith('{')), None)
        if report is None:
            raise RuntimeError(f'{name}: no report')
        return name, report

    reports = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        for name, report in pool.map(run, jobs):
            reports[name] = report
            print(f'{name}: clear={report["clear"]}, seconds={report["seconds"]}, deaths={report.get("deaths", "invincible")}', flush=True)
    (log_dir / 'balance_suite.json').write_text(json.dumps(reports, ensure_ascii=False, indent=2), encoding='utf-8')
    # Authored regression budgets, not universal or human difficulty thresholds.
    failures = []
    for name, report in reports.items():
        if not report['clear']:
            failures.append(f'{name}: did not clear (game over or trial timeout)')
    weak = reports['aim_lv1']['encounters']
    if len(weak) != 4 or any(e['duration'] > 38 for e in weak[:3]) or weak[-1]['duration'] > 70:
        failures.append('LV1 encounter duration exceeds the authored 38s middle / 70s boss budget')
    strong = reports['aim_lv3']['encounters']
    if len(strong) != 4 or any(not 12 <= e['duration'] <= 18 for e in strong[:3]) or not 25 <= strong[-1]['duration'] <= 40:
        failures.append('LV3 misses the 12–18s middle / 25–40s boss duration target')
    if not reports['recovery']['forced_recovery'] or reports['recovery']['deaths'] > 2:
        failures.append('Recovery trial did not inject its death or suffered more than one additional death')
    if reports['weak_no_bombs']['deaths'] > 2:
        failures.append('Weak no-bomb trial exceeded the two-loss budget')
    for section in ('middle_50_120', 'late_120_150'):
        density = reports['slow_reactive']['density'].get(section)
        if density is None:
            failures.append(f'{section}: trial ended before reaching this section')
            continue
        if density['no_target_percent'] > 20 or density['mean_visible'] < 1.5:
            failures.append(f'{section}: engagement density below the authored target')
        if density['two_source_window_percent'] < 15:
            failures.append(f'{section}: fewer than 15% of frames have two recent firing sources')
    if options.boss_patterns:
        _, camping = run(('boss_camping', 'boss_pattern_probe', []))
        safe = [(name, trial['y_fraction']) for name, trials in camping.items() for trial in trials if trial['contacts'] == 0]
        if safe:
            failures.append(f'Stationary 20s boss samples remain unchallenged: {safe}')
        print(f'Boss stationary samples: {25 - len(safe)}/25 exposed; not a human difficulty test')
    print(f'Reports: {log_dir}')
    if failures:
        raise SystemExit('\n'.join(failures))
    print('Balance regression budgets: PASS')


if __name__ == '__main__':
    main()
