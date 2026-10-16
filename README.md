# Last Night at Camp

Original top-down cooperative woodland horror game in Godot 4. The authoritative
project specification is [AGENT_BRIEF.md](AGENT_BRIEF.md); the supplied `.docx`
brief is also retained in the repository.

**Current milestone: M1 with requested woods/replayability expansion.** Choose
Woods Expedition for a seeded trail maze, five-part repair job, survival supplies,
and two roaming cryptids alongside the camp stalker. Find boltcutters in
Maintenance, search cabins for battery/key and woods caches for three more parts,
install them at the rear of the van, then hold E to start it. Starting automatically
seats the driver; other survivors press E beside the running van to board.
Passengers are safe inside until automatic departure. A stalker patrols, hears
sprinting, chases on sight, and searches where it last sensed you. Getting caught
twice or bleeding out ends the round. Replay and return to menu are available.
Quick Camp preserves the shorter battery/fuel/key round. Enter a seed on the menu
to replay a particular expedition; results offer a fresh night or the same seed.
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

Controls: WASD/arrows walk, Shift sprint, E interact/hold, F flashlight, Q flare,
R spare battery, C rations, Tab field notes/map, Esc pause. Woods flashlights drain
while on; ration packs restore stamina. Medkits shorten teammate revive holds.
Tab shows camp supply clues and reveals woods trails as you explore.
Building doors face south. Sprinting makes noise; use it to break a chase, then
walk quietly. The van leaves eight seconds after its engine starts. Only boarded
survivors extract; standing nearby does not count as entering.

The full map spans 3456×1920, 4.5 times the previous camp's bounds, including a
1600×1600 woods maze with 100 connected clearings, loops and six ruined landmarks.
The authored camp retains ten buildings, a dense
forest, trails, lakeshore and dock. Interiors include bedrooms, offices, a kitchen,
dining tables, showers, medical beds, and canoe storage. Roofs cut away as you
enter. Original directional camper/stalker sprite sheets replace the basic shapes.
Native flashlight shadows, warm lamps and headlights illuminate a much darker
nighttime map. Unlit woods are nearly black. Fog shortens flashlight/sight range;
rain reduces enemy hearing. Trails, cache contents, supply placements, camp
patrols, weather and the two-cryptid roster vary with the seed.

Werewolves charge in bursts with recovery windows; Bigfoot hears farther; lantern
moths track light. Flares repel the stalker, wolf and Bigfoot but attract moths.
Each cryptid has original directional 64×64 walking art. The menu, loading card,
field guide and results share the new forest palette.
See [asset source/provenance](assets/README.md).

Verified with automated input playthroughs and inspected screenshots on macOS
arm64 / Godot 4.7.2. Human playtesting, multiplayer, and other desktop platforms
are still unverified. Multiple-survivor boarding/revive use local test fixtures
until networking exists.
