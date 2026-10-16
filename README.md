# Last Night at Camp

Original top-down cooperative woodland horror game in Godot 4. The authoritative
project specification is [AGENT_BRIEF.md](AGENT_BRIEF.md); the supplied `.docx`
brief is also retained in the repository.

**Current milestone: M1 — playable offline survival round.** Play Solo, search
three cabins for a battery, fuel and key, install them at the rear of the van,
hold E to start it, and stay nearby through departure. A stalker patrols, hears
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
Esc pause. The three cabin doors face south. Sprinting makes noise; use it to
break a chase, then walk quietly. The van leaves five seconds after its engine
starts; a living survivor must remain in its extraction area to win.

Verified with automated input playthroughs and inspected screenshots on macOS
arm64 / Godot 4.7.2. Human playtesting, multiplayer, and other desktop platforms
are still unverified. Original geometric art is temporary.
