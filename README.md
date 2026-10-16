# Last Night at Camp

Original top-down cooperative woodland horror game in Godot 4. The authoritative
project specification is [AGENT_BRIEF.md](AGENT_BRIEF.md); the supplied `.docx`
brief is also retained in the repository.

**Current milestone: M1 — playable offline survival round, expanded camp.** Play
Solo, search the bunk cabin, workshop and ranger lodge for battery/fuel/key,
install them at the rear of the van, then hold E to start it. Starting automatically
seats the driver; other survivors press E beside the running van to board.
Passengers are safe inside until automatic departure. A stalker patrols, hears
sprinting, chases on sight, and searches where it last sensed you. Getting caught
twice or bleeding out ends the round. Replay and return to menu are available.
Multiplayer is the next milestone and is not implemented yet.

Requires Godot **4.7.2 stable** and Python 3 for helper scripts. No plugins,
third-party packages, or export templates are required to run from source.

```sh
python3 tools/run_game.py --editor  # Open the project
python3 tools/run_game.py           # Run the opening menu
python3 tools/verify.py             # Import, parse, mechanics, full win/loss tests
python3 tools/verify.py --graphical # Also run and capture real graphical rounds
```

Tools detect `godot`, `godot4`, or `/Applications/Godot.app/Contents/MacOS/Godot`.
Set `GODOT_BIN` to use another executable. Open `project.godot` directly in Godot
and press F5 as an alternative. See [setup/testing](docs/testing.md),
[architecture](docs/architecture.md), [milestone plan](docs/milestones.md), and
[development log](docs/development_log.md) for evidence and next steps.

Controls: WASD/arrows walk, Shift sprint, E interact/hold, F flashlight, Tab pack,
Esc pause. Tab opens both the pack and camp map, with numbered supply locations.
Building doors face south. Sprinting makes noise; use it to break a chase, then
walk quietly. The van leaves eight seconds after its engine starts. Only boarded
survivors extract; standing nearby does not count as entering.

The camp is 1536×960, four times the original area, with ten buildings, a dense
forest, trails, lakeshore and dock. Interiors include bedrooms, offices, a kitchen,
dining tables, showers, medical beds, and canoe storage. Roofs cut away as you
enter. Original directional camper/stalker sprite sheets replace the basic shapes.
Native flashlight shadows, warm lamps and headlights illuminate a much darker
nighttime map. See [asset source/provenance](assets/README.md).

Verified with automated input playthroughs and inspected screenshots on macOS
arm64 / Godot 4.7.2. Human playtesting, multiplayer, and other desktop platforms
are still unverified. Multiple-survivor boarding/revive use local test fixtures
until networking exists.
