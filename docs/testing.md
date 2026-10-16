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
The menu offers Woods Expedition / Quick Camp, an optional seed, Enter the Night,
Controls and Quit. Click or use Tab/arrows and Enter. Escape closes the field
guide. Enter the Night starts the selected offline mode via the loading card.

WASD/arrows walk; Shift sprints and consumes stamina; E picks up or installs
supplies; hold E to start the repaired van or revive a nearby downed teammate;
F toggles the flashlight; Q throws a flare; R consumes a spare flashlight battery;
C consumes rations; Tab toggles notes/map; Esc pauses. Teammate revive is
implemented and fixture-tested, but there is only one human survivor in M1.
In Quick Camp, Tab opens the pack and field map with numbered locations: battery in the
west bunk cabin, fuel in Maintenance, key in the Ranger Lodge. Building doors face
south; roof cutaways reveal furnished interiors. Deliver all parts at the rear
of the van and hold E for two seconds. This automatically boards the driver and
displays YOU ARE ABOARD. Other living survivors press E beside the running van
to enter during the eight-second departure countdown. Passengers cannot move out
or be hit. Survivors who stay outside are left behind even if they stand nearby.
A first killer hit downs you; a second or bleed-out eliminates you.
Solo has no self-revive. Woods Expedition instead requires five parts, including
three locked woods caches opened with boltcutters from Maintenance. Tab reveals
woods trails as you explore. Torch charge drains in the woods; collect spare
batteries, flares, food and medkits. Fog shortens sight/beam; rain muffles hearing.
Results offer a new seed, retry same seed, or menu return. Retrying starts with
fresh actors/inventory, not a saved checkpoint.

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
godot --headless --path . --fixed-fps 60 --disable-vsync --script res://tests/integration/woods_replay.gd
godot --headless --path . --fixed-fps 60 --disable-vsync --script res://tests/integration/woods_playthrough.gd
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
It walks to all three supply buildings with collision enabled, collects/delivers every
part using E, sprints to escape a real chase, starts the van, wins, restarts,
walks onto the patrol route for a loss, then returns to the menu. The killer and
default rules remain active throughout; no teleports or health/objective edits.
This is automated playability evidence, not a claimed human playtest.

`camp_upgrade.gd` verifies the larger map and entrances/objectives are reachable,
roof cutaway/restoration, automatic and explicit boarding, rejected distant/downed
or duplicate boarding, passenger safety, and escaped/left-behind results. Multiple
survivors are fixtures. Its graphical tour captures interiors, campsite, shore,
field map and character art. A matched flashlight on/off probe verifies dark
terrain brightens in the beam; this sample does not measure the whole map.

`woods_replay.gd` verifies eight seeds for reproducible topology/loot/encounters,
100 connected clearings, six landmarks, one of each of five required parts,
tools/supplies and roster/weather variety. Seeds 42 and 2026 bake real worlds and
check native navigation to every item/landmark. Isolated fixtures cover locked
cache/tool/proximity rules, battery depletion/refill, rations, flare placement and
pause, species sensing, flare responses, wolf charge recovery, seed retry/new run
and scene cleanup. The graphical tour captures loading, woods darkness, all six
cryptids, landmarks, notes and results. These fixtures intentionally place actors
and disable AI to inspect individual rules/art; they are not a full playthrough.

`woods_playthrough.gd` completes seed 42 through ordinary movement/interact/supply
input with production damage, speeds and all enemies active. The automated
route guide uses native paths, so it knows trail connectivity; it is not evidence
of human maze difficulty or balance across every seed. It prepares in camp,
collects all five parts, uses flares/sprint when threatened, returns, boards and
escapes. No teleports, health/inventory edits, or AI disabling occur. Both modes
run this expedition; the graphical variant saves the real escape result.

Manual acceptance still to record: launch normally, play an entire win or loss
at real-time speed, restart, and check that dark regions, prompts, and keyboard
controls feel readable. The rules suite also verifies pause during departure,
an empty van losing, and unboarded survivors being left behind. Explore each building manually
to assess comfort and visual clarity beyond these automated routes. Also verify
that the automatic driver entry and explicit E-to-board prompt feel unambiguous.

Human playtesting, multiplayer, cross-platform exports, Gatekeeper and
SmartScreen remain unverified. Host/client launch scripts and protocol
assertions will be added in M2 with an actual implementation, not stub flags.
Network acceptance must include two real ENet clients; later cover four peers,
single-award pickup races, shared downed/repair/extraction state, restart and
disconnect cleanup. Unsigned desktop release notes belong to M4.

## Forest hunt coverage

The updated woods recipe checks four distinct cryptids (vampire/witch guaranteed),
three expanded themed sites, all required items and abstract clearings in the
native bake. Clearing destinations inside furnished huts use their nearest
walkable point; item and hut entrance assertions still require exact access.
The active Woods test uses ordinary E to search the village well and graveyard
crypt as preparation; all five enemies remain active throughout the escape.
The Quick Camp bot now also uses its existing Q/C supplies when threatened.
No game damage, speed, health or inventory is edited by either playthrough.

`forest_hunt.gd` adds isolated fixtures for both hut interiors, broad patrol
coverage and actual roaming movement, finite/no-duplicate site rewards,
remote-interaction rejection, bell stimuli/cooldown, cauldron trade-off,
vampire beam/flank behavior, motion-sensitive revenant sensing, multiple-point
search without hidden-target updates, witch wind-up/fire, hex application,
swept projectile wall collision, blocked casting, dodging, pause and cleanup.
Its graphical variant captures the three sites, witch telegraph and moving bolt.
Site/creature screenshots use deliberate actor placement and camera composition;
they are distinct from the complete active playthrough evidence.

## Camp layout polish

`tests/integration/layout_polish.gd` checks eight distinct/reproducible expedition
camps, road/building reservations, native paths to every camp entrance and every
pickup. The graphical version captures seed 42 and 2026 overviews with an
inspection camera/raised ambient light; normal play retains its usual camera and
lighting. Quick Camp remains the fixed tutorial route.
