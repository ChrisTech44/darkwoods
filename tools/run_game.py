"""Launch from any working directory; engine arguments pass through unchanged.

Godot's .godot/ cache (script-class list and imported textures/sounds) is not
in git. A fresh clone, or an editor closed before its first import finished,
leaves it missing or incomplete, so every launch first runs Godot's import.
It only processes new or changed files: about 2 seconds when up to date, about
a minute the first time. Pass --no-import to skip it.
"""

import subprocess
import sys
from pathlib import Path

from godot_cli import ROOT, godot_binary


def missing_imports() -> list[str]:
    """Assets whose imported file Godot would need but cannot find."""
    missing = []
    for meta in ROOT.rglob("*.import"):
        if ".godot" in meta.parts:
            continue
        for line in meta.read_text(encoding="utf-8", errors="ignore").splitlines():
            if line.startswith("path=") or line.startswith('path.'):
                target = line.split("=", 1)[1].strip().strip('"')
                if target.startswith("res://") and not (ROOT / target[6:]).is_file():
                    missing.append(str(meta.relative_to(ROOT))[:-7])
                break
    return missing


if __name__ == "__main__":
    engine = godot_binary()
    arguments = [argument for argument in sys.argv[1:] if argument not in ("--no-import", "--reimport")]
    if "--no-import" not in sys.argv:
        if not (ROOT / ".godot" / "global_script_class_cache.cfg").is_file() or missing_imports():
            print("Importing the project (about a minute the first time)...", flush=True)
        subprocess.call([engine, "--headless", "--path", str(ROOT), "--import"], cwd=ROOT)
        still = missing_imports()
        if still:
            print(f"Warning: {len(still)} assets still not imported, e.g. {still[0]}.", flush=True)
            print("Open the project once in the Godot editor and let the import finish.", flush=True)
    raise SystemExit(subprocess.call([engine, "--path", str(ROOT), *arguments], cwd=ROOT))
