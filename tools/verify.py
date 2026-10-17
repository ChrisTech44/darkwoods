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
    upgrade = ["--path", str(ROOT), "--fixed-fps", "60", "--disable-vsync", "--script", "res://tests/integration/camp_upgrade.gd"]
    commands.append(("camp_upgrade", ["--headless", *upgrade]))
    woods = ["--path", str(ROOT), "--fixed-fps", "60", "--disable-vsync", "--script", "res://tests/integration/woods_replay.gd"]
    commands.append(("woods_replay", ["--headless", *woods]))
    expedition = ["--path", str(ROOT), "--fixed-fps", "60", "--disable-vsync", "--script", "res://tests/integration/woods_playthrough.gd"]
    commands.append(("woods_playthrough", ["--headless", *expedition]))
    hunt = ["--path", str(ROOT), "--fixed-fps", "60", "--disable-vsync", "--script", "res://tests/integration/forest_hunt.gd"]
    commands.append(("forest_hunt", ["--headless", *hunt]))
    seeds = ["--headless", "--path", str(ROOT), "--script", "res://tests/integration/navigation_seeds.gd"]
    commands.append(("navigation_seeds", seeds))
    surround = ["--path", str(ROOT), "--fixed-fps", "60", "--disable-vsync", "--script", "res://tests/integration/surround_world.gd"]
    commands.append(("surround_world", ["--headless", *surround]))
    visibility = ["--path", str(ROOT), "--fixed-fps", "60", "--disable-vsync", "--script", "res://tests/integration/woods_visibility.gd"]
    commands.append(("woods_visibility", ["--headless", *visibility]))
    treeline = ["--path", str(ROOT), "--script", "res://tests/integration/treeline.gd"]
    commands.append(("treeline", ["--headless", *treeline]))
    defaults = ["--path", str(ROOT), "--fixed-fps", "60", "--disable-vsync", "--script", "res://tests/integration/menu_defaults.gd"]
    shadows = ["--path", str(ROOT), "--fixed-fps", "60", "--disable-vsync", "--script", "res://tests/integration/woods_shadows.gd"]
    commands.append(("menu_defaults", ["--headless", *defaults]))
    commands.append(("woods_shadows", ["--headless", *shadows]))
    audio = ["--path", str(ROOT), "--fixed-fps", "60", "--disable-vsync", "--script", "res://tests/integration/audio_polish.gd"]
    commands.append(("audio_polish", ["--headless", *audio, "--", "--audio-test"]))
    polish = ["--path", str(ROOT), "--fixed-fps", "60", "--disable-vsync", "--script", "res://tests/integration/layout_polish.gd"]
    commands.append(("layout_polish", ["--headless", *polish]))
    render = ["--path", str(ROOT), "--script", "res://tests/integration/player_render.gd"]
    commands.append(("player_render", ["--headless", *render]))
    content = ["--path", str(ROOT), "--fixed-fps", "60", "--disable-vsync", "--script", "res://tests/integration/content_expansion.gd"]
    commands.append(("content_expansion", ["--headless", *content]))
    navigation = ["--path", str(ROOT), "--fixed-fps", "60", "--disable-vsync", "--script", "res://tests/integration/navigation_aids.gd"]
    commands.append(("navigation_aids", ["--headless", *navigation]))
    nights = ["--path", str(ROOT), "--fixed-fps", "60", "--disable-vsync", "--script", "res://tests/integration/night_phases.gd"]
    commands.append(("night_phases", ["--headless", *nights]))
    chase = ["--path", str(ROOT), "--fixed-fps", "60", "--disable-vsync", "--script", "res://tests/integration/chase_toolkit.gd"]
    commands.append(("chase_toolkit", ["--headless", *chase]))
    chase_props = ["--path", str(ROOT), "--fixed-fps", "60", "--disable-vsync", "--script", "res://tests/integration/chase_props.gd"]
    commands.append(("chase_props", ["--headless", *chase_props]))
    roads = ["--path", str(ROOT), "--fixed-fps", "60", "--disable-vsync", "--script", "res://tests/integration/road_network.gd"]
    commands.append(("road_network", ["--headless", *roads]))
    clues = ["--path", str(ROOT), "--fixed-fps", "60", "--disable-vsync", "--script", "res://tests/integration/rotation_clues.gd"]
    commands.append(("rotation_clues", ["--headless", *clues]))
    barriers = ["--path", str(ROOT), "--fixed-fps", "60", "--disable-vsync", "--script", "res://tests/integration/barriers.gd"]
    commands.append(("barriers", ["--headless", *barriers]))
    rescue = ["--path", str(ROOT), "--fixed-fps", "60", "--disable-vsync", "--script", "res://tests/integration/radio_rescue.gd"]
    commands.append(("radio_rescue", ["--headless", *rescue]))
    field_escapes = ["--path", str(ROOT), "--fixed-fps", "60", "--disable-vsync", "--script", "res://tests/integration/field_escapes.gd"]
    commands.append(("field_escapes", ["--headless", *field_escapes]))
    if args.graphical:
        commands.append(("graphical_field_escapes", ["--audio-driver", "Dummy", *field_escapes, "--", "--capture"]))
        commands.append(("graphical_rescue", ["--audio-driver", "Dummy", *rescue, "--", "--capture"]))
        commands.append(("graphical_player_render", ["--audio-driver", "Dummy", *render]))
        commands.append(("graphical_content", ["--audio-driver", "Dummy", *content, "--", "--capture"]))
        commands.append(("graphical_navigation", ["--audio-driver", "Dummy", *navigation, "--", "--capture"]))
        commands.append(("graphical_nights", ["--audio-driver", "Dummy", *nights, "--", "--capture"]))
        commands.append(("graphical_chase", ["--audio-driver", "Dummy", *chase, "--", "--capture"]))
        commands.append(("graphical_props", ["--audio-driver", "Dummy", *chase_props, "--", "--capture"]))
        commands.append(("graphical_roads", ["--audio-driver", "Dummy", *roads, "--", "--capture"]))
        commands.append(("graphical_clues", ["--audio-driver", "Dummy", *clues, "--", "--capture"]))
        commands.append(("graphical_barriers", ["--audio-driver", "Dummy", *barriers, "--", "--capture"]))
        commands.append(("graphical_surround", [*surround, "--", "--capture"]))
        commands.append(("graphical_visibility", [*visibility, "--", "--capture"]))
        commands.append(("graphical_treeline", treeline))
        commands.append(("graphical_defaults", [*defaults, "--", "--capture"]))
        commands.append(("graphical_shadows", [*shadows, "--", "--capture"]))
        commands.append(("graphical_audio", ["--audio-driver", "Dummy", *audio, "--", "--audio-test", "--capture"]))
        commands.append(("graphical_polish", [*polish, "--", "--capture"]))
        commands.append(("graphical_smoke", [*smoke, "--", "--capture"]))
        commands.append(("graphical_offline", [*offline, "--", "--capture"]))
        commands.append(("graphical_playthrough", [*playthrough, "--", "--capture"]))
        commands.append(("graphical_upgrade", [*upgrade, "--", "--capture"]))
        commands.append(("graphical_woods", [*woods, "--", "--capture"]))
        commands.append(("graphical_expedition", [*expedition, "--", "--capture"]))
        commands.append(("graphical_hunt", [*hunt, "--", "--capture"]))
    results = []
    for name, arguments in commands:
        command = [engine, *arguments]
        timed_out = False
        timeout = 240 if name in ("graphical_expedition", "woods_playthrough", "graphical_polish", "layout_polish", "chase_props", "woods_replay", "graphical_woods", "menu_defaults", "graphical_defaults", "surround_world", "graphical_surround", "navigation_seeds") else 90
        try:
            result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, text=True, timeout=timeout)
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
        if name in ("field_escapes", "graphical_field_escapes", "radio_rescue", "graphical_rescue", "player_render", "graphical_player_render", "content_expansion", "graphical_content", "navigation_aids", "graphical_navigation", "night_phases", "graphical_nights", "chase_toolkit", "graphical_chase", "chase_props", "graphical_props", "road_network", "graphical_roads", "rotation_clues", "graphical_clues", "barriers", "graphical_barriers", "menu_smoke", "graphical_smoke", "offline_slice", "graphical_offline", "offline_playthrough", "graphical_playthrough", "camp_upgrade", "graphical_upgrade", "woods_replay", "graphical_woods", "woods_playthrough", "graphical_expedition", "forest_hunt", "graphical_hunt", "layout_polish", "graphical_polish", "audio_polish", "graphical_audio", "menu_defaults", "graphical_defaults", "woods_shadows", "graphical_shadows", "woods_visibility", "graphical_visibility", "surround_world", "graphical_surround", "navigation_seeds"):
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
