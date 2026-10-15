"""Launch from any working directory; engine arguments pass through unchanged."""

import subprocess
import sys

from godot_cli import ROOT, godot_binary

if __name__ == "__main__":
    raise SystemExit(subprocess.call([godot_binary(), "--path", str(ROOT), *sys.argv[1:]], cwd=ROOT))
