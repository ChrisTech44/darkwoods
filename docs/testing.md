# Running and verification

Use Godot **4.7.2 stable** (standard/GDScript build, not .NET) and Python 3. No
Python packages are needed. Install Godot from its official distribution and put
its executable on PATH as `godot` or `godot4`. On macOS the tools also detect
`/Applications/Godot.app/Contents/MacOS/Godot`. Override with `GODOT_BIN` if needed:

```sh
GODOT_BIN=/absolute/path/to/godot python3 tools/verify.py
```

On Windows use Python via `py -3` if `python3` is unavailable, and set `GODOT_BIN`
to the executable in your shell environment. Windows/Linux execution is unverified.
The setup is intentionally source-based until M4; no export templates are needed
to run or test M0 in Godot.

## Launch

From the repository root:

```sh
godot --version
python3 tools/run_game.py --editor
python3 tools/run_game.py
```

Or open `project.godot` in Godot and press F6 on the menu or F5 for the project.
The menu offers Controls and Quit. Click buttons or use Tab/arrows and Enter.
Escape closes the field guide. Play is visibly disabled in M0.

## Repeatable checks after changes

```sh
python3 tools/verify.py
python3 tools/verify.py --graphical
```

The second command also opens a real Godot window, exercises the menu through
keyboard input, captures the menu and guide, then exits. It requires a desktop
session. Inspect the saved PNGs; headless success alone is not visual evidence.
The runner records each exact command, exit status, errors and warnings separately
in `artifacts/verification/summary.json` and raw per-step `.log` files. It fails on
nonzero exit, engine `ERROR:` output even with exit 0, timeout, missing test summary,
or failed assertions. Warnings remain visible in the report for review.

Equivalent individual commands:

```sh
godot --headless --path . --import
godot --headless --path . --quit-after 5
godot --headless --path . --script res://scripts/ui/main_menu.gd --check-only
godot --headless --path . --script res://scripts/ui/menu_backdrop.gd --check-only
godot --headless --path . --script res://tests/integration/menu_smoke.gd --check-only
godot --headless --path . --script res://tests/integration/menu_smoke.gd
godot --path . --script res://tests/integration/menu_smoke.gd -- --capture
```

Godot writes its normal user data and editor caches outside the repository. In a
restricted agent sandbox those writes and graphical sessions may need approval;
do not interpret a zero process exit as success when engine errors were printed.

## Coverage and limits

M0 checks boot loading, every specified physical key binding, viewport/filter
settings, keyboard focus, opening Controls with Enter, closing with Escape and
Back, and disabled unfinished Play. These are scene/input checks, not gameplay.

No movement, AI, objective, multiplayer, cross-platform export, Gatekeeper or
SmartScreen behavior has been tested. Host/client launch scripts and protocol
assertions will be added in M2 with an actual implementation, not stub flags.
Network acceptance must include two real ENet clients; later cover four peers,
single-award pickup races, shared downed/repair/extraction state, restart and
disconnect cleanup. Unsigned desktop release notes belong to M4.
