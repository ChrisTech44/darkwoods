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
to run or test M1 in Godot.

## Launch

From the repository root:

```sh
godot --version
python3 tools/run_game.py --editor
python3 tools/run_game.py
```

Or open `project.godot` in Godot and press F6 on the menu or F5 for the project.
The menu offers Play Solo, Controls and Quit. Click or use Tab/arrows and Enter.
Escape closes the field guide. Play Solo starts the offline round.

WASD/arrows walk; Shift sprints and consumes stamina; E picks up or installs
supplies; hold E to start the repaired van or revive a nearby downed teammate;
F toggles the flashlight; Tab toggles inventory; Esc pauses. Teammate revive is
implemented and fixture-tested, but there is only one human survivor in M1.
Search the three cabins, whose doors face south. Deliver battery/fuel/key at the
rear of the van, hold E for two seconds, then remain nearby for the five-second
countdown. A first killer hit downs you; a second or bleed-out eliminates you.
Solo has no self-revive. Both result screens offer replay and menu return.

## Repeatable checks after changes

```sh
python3 tools/verify.py
python3 tools/verify.py --graphical
```

The second command also opens a real Godot window, exercises the menu through
keyboard input, runs mechanic fixtures and complete input-driven win/loss rounds,
captures screenshots, then exits. It requires a desktop session. Inspect the PNGs;
headless success alone is not visual evidence. Fixed 60 Hz and disabled VSync
allow automated playthroughs to run faster; normal gameplay uses real time.
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
godot --headless --path . --fixed-fps 60 --disable-vsync --script res://tests/integration/offline_slice.gd
godot --headless --path . --fixed-fps 60 --disable-vsync --script res://tests/integration/offline_playthrough.gd
godot --path . --fixed-fps 60 --disable-vsync --script res://tests/integration/offline_playthrough.gd -- --capture
```

Godot writes its normal user data and editor caches outside the repository. In a
restricted agent sandbox those writes and graphical sessions may need approval;
do not interpret a zero process exit as success when engine errors were printed.

## Coverage and limits

`menu_smoke.gd` checks boot, every physical key binding, viewport/filter settings,
keyboard focus, Controls/Back/Escape, and enabled solo Play.

`offline_slice.gd` uses explicit isolated placements to test real movement,
collision and cabin entry, stamina, proximity/availability/occlusion checks,
delivery and interrupted start holds, extraction, restart cleanup, killer
sight/hearing/memory/navigation, attack cooldown, timed revive/grace, second-hit
elimination and bleed-out. Teammates are fixtures, not connected human clients.

`offline_playthrough.gd` starts at the real menu and uses normal input only.
It walks through all three cabins with collision enabled, collects/delivers every
part using E, sprints to escape a real chase, starts the van, wins, restarts,
walks onto the patrol route for a loss, then returns to the menu. The killer and
default rules remain active throughout; no teleports or health/objective edits.
This is automated playability evidence, not a claimed human playtest.

Manual acceptance still to record: launch normally, play an entire win or loss
at real-time speed, restart, and check that dark regions, prompts, and keyboard
controls feel readable. The rules suite also verifies pause during departure and
losing when outside the extraction zone. Explore around every cabin/tree manually
to assess comfort and visual clarity beyond these automated routes.

Human playtesting, multiplayer, cross-platform exports, Gatekeeper and
SmartScreen remain unverified. Host/client launch scripts and protocol
assertions will be added in M2 with an actual implementation, not stub flags.
Network acceptance must include two real ENet clients; later cover four peers,
single-award pickup races, shared downed/repair/extraction state, restart and
disconnect cleanup. Unsigned desktop release notes belong to M4.
