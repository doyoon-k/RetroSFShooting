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
        if row["power"] != 3 or not row["enemy"].startswith("n"):
            continue
        lower, upper = (1.5, 2.5) if row["enemy"] in ("n3_claw", "n4_armor") else (0.9, 1.6)
        seconds = row["seconds_to_kill"]
        if seconds is None or not lower <= seconds <= upper:
            failures.append(f"Role TTK missed: {row}")
        print(f'{row["enemy"]} / {row["weapon"]}: {seconds}s, {row["bursts_completed"]} completed bursts')
    if failures:
        raise SystemExit("\n".join(failures))
    print("Durability targets: PASS. Stationary invincible trials; not survival validation.")


if __name__ == "__main__":
    main()
