"""Build a portable server PCK bundle; Godot of the recorded version is required."""
import json
import os
import re
import shutil
import subprocess
import tempfile
import zipfile
from pathlib import Path
from godot_cli import ROOT, godot_binary


def protocol_rules(root=ROOT):
    source = (root / 'scripts/network/network_session.gd').read_text()
    found = re.search(r'^const RULES\s*:=\s*"([^"]+)"', source, re.MULTILINE)
    if not found:
        raise ValueError('Cannot read the current game protocol; no bundle was published.')
    return found[1]


def build_bundle(engine, out):
    out.mkdir(parents=True, exist_ok=True)
    # Export into a fresh directory: a zero-exit/no-output export must never be
    # mistaken for a new build because last week's PCK still exists.
    with tempfile.TemporaryDirectory(prefix='server-build-', dir=out) as temp:
        stage = Path(temp)
        pack = stage / 'last-night-server.pck'
        result = subprocess.run([engine, '--headless', '--path', str(ROOT), '--export-pack', 'Dedicated Server', str(pack)],
                                cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        (out / 'export.log').write_text(result.stdout)
        if result.returncode or 'ERROR:' in result.stdout or 'WARNING:' in result.stdout or not pack.is_file() or not pack.stat().st_size:
            print(result.stdout)
            print('No new server bundle was published; any previous bundle is unchanged.')
            return 1
        version = subprocess.check_output([engine, '--version'], text=True).strip()
        match = re.match(r'\d+\.\d+(?:\.\d+)?', version)
        if not match:
            raise ValueError('Cannot identify the Godot runtime version.')
        launcher = stage / 'run-server.sh'
        launcher.write_text('#!/bin/sh\nset -eu\nserver_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)\nexec "${GODOT_BIN:-godot}" --headless --disable-render-loop --audio-driver Dummy --main-pack "$server_dir/last-night-server.pck" -- --dedicated-server "$@"\n')
        launcher.chmod(0o755)
        shutil.copyfile(ROOT / 'docs/dedicated_server.md', stage / 'README.md')
        metadata = {'engine': match[0], 'engine_build': version, 'rules': protocol_rules(),
                    'requires_runtime': 'Godot ' + match[0] + ' for the server OS',
                    'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                    'worktree_dirty': bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=ROOT, text=True).strip())}
        (stage / 'build.json').write_text(json.dumps(metadata, indent=2) + '\n')
        archive = stage / 'last-night-server.zip'
        names = [pack.name, launcher.name, 'README.md', 'build.json']
        with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as bundle:
            for name in names: bundle.write(stage / name, name)
        # The user-facing ZIP is replaced last and always contains one coherent
        # build; a failed export cannot overwrite it with stale/new mixed files.
        for name in [*names, archive.name]: os.replace(stage / name, out / name)
    print(out / 'last-night-server.zip')
    return 0


def main():
    return build_bundle(godot_binary(), ROOT / 'artifacts/server')


if __name__ == '__main__':
    raise SystemExit(main())
