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
    raise SystemExit("Godot not found. Install Godot 4.7.2 or set GODOT_BIN to its executable.")
