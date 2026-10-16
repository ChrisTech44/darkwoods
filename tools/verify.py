"""Import, parse, boot, and exercise the menu. Emit JSON results and raw logs."""

import argparse
from datetime import datetime, timezone
import json
import re
import subprocess

from godot_cli import ROOT, godot_binary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--graphical", action="store_true", help="Also open a real window and save screenshots.")
    args = parser.parse_args()
    engine = godot_binary()
    evidence = ROOT / "artifacts" / "verification"
    evidence.mkdir(parents=True, exist_ok=True)
    commands = [
        ("version", ["--version"]),
        ("import", ["--headless", "--path", str(ROOT), "--import"]),
        ("startup", ["--headless", "--path", str(ROOT), "--quit-after", "5"]),
    ]
    for script in sorted(ROOT.rglob("*.gd")):
        if any(part.startswith(".") for part in script.relative_to(ROOT).parts):
            continue
        relative = script.relative_to(ROOT).as_posix()
        commands.append(("parse_" + relative.replace("/", "_"), [
            "--headless", "--path", str(ROOT), "--script", "res://" + relative, "--check-only"
        ]))
    smoke = ["--path", str(ROOT), "--script", "res://tests/integration/menu_smoke.gd"]
    commands.append(("menu_smoke", ["--headless", *smoke]))
    offline = ["--path", str(ROOT), "--fixed-fps", "60", "--disable-vsync", "--script", "res://tests/integration/offline_slice.gd"]
    commands.append(("offline_slice", ["--headless", *offline]))
    playthrough = ["--path", str(ROOT), "--fixed-fps", "60", "--disable-vsync", "--script", "res://tests/integration/offline_playthrough.gd"]
    commands.append(("offline_playthrough", ["--headless", *playthrough]))
    if args.graphical:
        commands.append(("graphical_smoke", [*smoke, "--", "--capture"]))
        commands.append(("graphical_offline", [*offline, "--", "--capture"]))
        commands.append(("graphical_playthrough", [*playthrough, "--", "--capture"]))
    results = []
    for name, arguments in commands:
        command = [engine, *arguments]
        timed_out = False
        try:
            result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, text=True, timeout=60)
            output, status = result.stdout, result.returncode
        except subprocess.TimeoutExpired as error:
            raw = error.stdout or b""
            output = raw.decode(errors="replace") if isinstance(raw, bytes) else raw
            status, timed_out = 124, True
        clean = re.sub(r"\x1b\[[0-9;]*m", "", output)
        log = evidence / (name + ".log")
        log.write_text(clean, encoding="utf-8")
        errors = [line for line in clean.splitlines()
                  if re.search(r"(?:SCRIPT ERROR|ERROR|Parse Error):", line)]
        warnings = [line for line in clean.splitlines() if "WARNING:" in line]
        passed = status == 0 and not errors and not timed_out
        if name in ("menu_smoke", "graphical_smoke", "offline_slice", "graphical_offline", "offline_playthrough", "graphical_playthrough"):
            summaries = []
            for line in clean.splitlines():
                if line.startswith("{"):
                    event = json.loads(line)
                    if event.get("event") == "test_result":
                        summaries.append(event)
            passed = passed and len(summaries) == 1 and summaries[0]["failures"] == 0
        record = {"step": name, "command": command, "exit_code": status,
                  "passed": passed, "errors": errors, "warnings": warnings,
                  "timed_out": timed_out, "log": str(log.relative_to(ROOT))}
        results.append(record)
        print(json.dumps(record), flush=True)
        if not passed:
            print(clean, flush=True)
            break
    report = {"timestamp_utc": datetime.now(timezone.utc).isoformat(),
              "passed": len(results) == len(commands) and all(r["passed"] for r in results),
              "graphical": args.graphical, "results": results}
    (evidence / "summary.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
