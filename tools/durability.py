"""Measure role durability at 400px center distance using actual projectile collisions.
Run alongside tools/balance.py for moving major encounters and recovery tests.
"""
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def main():
    executable = shutil.which("godot")
    if not executable:
        raise SystemExit("Godot executable not found")
    output = ROOT / "build/validation"
    output.mkdir(parents=True, exist_ok=True)
    result = subprocess.run([str(Path(executable).resolve()), "--headless", "--path", str(ROOT),
                             "--audio-driver", "Dummy", "--script", "tests/weapon_pressure_probe.gd",
                             "--fixed-fps", "60", "--", "--durability"],
                            cwd=ROOT, capture_output=True, encoding="utf-8", errors="replace", timeout=240)
    log = result.stdout + result.stderr
    (output / "durability.log").write_text(log, encoding="utf-8")
    if result.returncode or re.search(r"SCRIPT ERROR|ERROR:|WARNING:", log):
        raise SystemExit(log)
    rows = next((json.loads(line) for line in result.stdout.splitlines() if line.startswith("[")), [])
    failures = []
    if len(rows) != 36:
        failures.append("Expected nine enemies x two weapons x two power levels")
    for row in rows:
        if not row["defeated"]:
            failures.append(f"Timed out: {row}")
        if not row["enemy"].startswith("n"):
            continue
        seconds = row["seconds_to_kill"]
        # Full-clear routing now takes priority over guaranteeing an enemy burst.
        # LV1 straight must leave time to change lanes; LV3 can interrupt attacks.
        upper = 2.2 if row["enemy"] in ("n3_claw", "n4_armor") else 1.5
        check_budget = row["power"] == 3 or row["weapon"] == "straight"
        if check_budget and (seconds is None or not 0.0 < seconds <= upper):
            failures.append(f"Role TTK missed: {row}")
        print(f'{row["enemy"]} / {row["weapon"]} LV{row["power"]}: {seconds}s')
    if failures:
        raise SystemExit("\n".join(failures))
    print("Durability targets: PASS. Stationary invincible trials; not survival validation.")


if __name__ == "__main__":
    main()
