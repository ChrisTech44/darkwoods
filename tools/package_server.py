"""Build a portable server PCK bundle (requires Godot 4.7.2 at runtime)."""
import json
import shutil
import subprocess
import zipfile
from pathlib import Path
from godot_cli import ROOT, godot_binary


def main():
    out = ROOT / "artifacts/server"
    out.mkdir(parents=True, exist_ok=True)
    pack = out / "last-night-server.pck"
    result = subprocess.run([godot_binary(), "--headless", "--path", str(ROOT), "--export-pack", "Dedicated Server", str(pack)],
                            cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    (out / "export.log").write_text(result.stdout)
    if result.returncode or "ERROR:" in result.stdout or "WARNING:" in result.stdout or not pack.exists():
        print(result.stdout)
        return 1
    launcher = out / "run-server.sh"
    launcher.write_text('#!/bin/sh\nset -eu\nserver_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)\nexec "${GODOT_BIN:-godot}" --headless --disable-render-loop --audio-driver Dummy --main-pack "$server_dir/last-night-server.pck" -- --dedicated-server "$@"\n')
    launcher.chmod(0o755)
    shutil.copyfile(ROOT / "docs/dedicated_server.md", out / "README.md")
    metadata = {"engine": "4.7.2", "rules": "lnac-net-17", "requires_runtime": "Godot 4.7.2 for the server OS", "commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()}
    (out / "build.json").write_text(json.dumps(metadata, indent=2) + "\n")
    archive = out / "last-night-server.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as bundle:
        for name in [pack.name, launcher.name, "README.md", "build.json"]:
            bundle.write(out / name, name)
    print(archive)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
