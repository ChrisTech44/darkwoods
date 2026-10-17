"""Launch from any working directory; engine arguments pass through unchanged.

A fresh clone or ZIP has no .godot/ folder (it is not in git). Godot only builds
it, including the script-class list and the imported textures, when the
project is imported, so the first launch imports automatically.
"""

import subprocess
import sys

from godot_cli import ROOT, godot_binary


def imported() -> bool:
    cache = ROOT / ".godot"
    return (cache / "global_script_class_cache.cfg").is_file() and (cache / "imported").is_dir()


if __name__ == "__main__":
    engine = godot_binary()
    if not imported() or "--reimport" in sys.argv:
        print("First launch: importing the project (about a minute)...", flush=True)
        subprocess.call([engine, "--headless", "--path", str(ROOT), "--import"], cwd=ROOT)
    arguments = [argument for argument in sys.argv[1:] if argument != "--reimport"]
    raise SystemExit(subprocess.call([engine, "--path", str(ROOT), *arguments], cwd=ROOT))
