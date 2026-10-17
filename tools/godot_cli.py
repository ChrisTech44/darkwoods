"""Shared local Godot discovery. No downloads or third-party dependencies."""

import os
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parent.parent


def godot_binary():
    override = os.environ.get("GODOT_BIN")
    if override:
        return override
    for name in ("godot", "godot4"):
        executable = shutil.which(name)
        if executable:
            return executable
    mac_app = Path("/Applications/Godot.app/Contents/MacOS/Godot")
    if mac_app.is_file():
        return str(mac_app)
    # Windows/Linux downloads keep their versioned names (e.g.
    # Godot_v4.7.2-stable_win64.exe); look beside the project and in Downloads.
    for folder in (ROOT, ROOT.parent, Path.home() / "Downloads", Path.home() / "Desktop"):
        if folder.is_dir():
            found = sorted(p for p in folder.glob("Godot_v4*") if p.is_file() and "console" not in p.name.lower())
            if found:
                return str(found[-1])
    raise SystemExit("Godot not found. Install Godot 4.7.2 or set GODOT_BIN to its executable.")
