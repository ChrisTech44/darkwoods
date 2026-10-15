# Last Night at Camp

Original top-down cooperative woodland horror game in Godot 4. The authoritative
project specification is [AGENT_BRIEF.md](AGENT_BRIEF.md); the supplied `.docx`
brief is also retained in the repository.

**Current milestone: M0 — project, opening menu, controls guide, verification.**
Gameplay and multiplayer are not implemented yet. Play is disabled.

Requires Godot **4.7.2 stable** and Python 3 for helper scripts. No plugins,
third-party packages, or export templates are required for this milestone.

```sh
python3 tools/run_game.py --editor  # Open the project
python3 tools/run_game.py           # Run the opening menu
python3 tools/verify.py             # Import, parse, boot, and menu assertions
python3 tools/verify.py --graphical # Also capture menu/controls in a real window
```

Tools detect `godot`, `godot4`, or `/Applications/Godot.app/Contents/MacOS/Godot`.
Set `GODOT_BIN` to use another executable. Open `project.godot` directly in Godot
and press F5 as an alternative. See [setup/testing](docs/testing.md),
[architecture](docs/architecture.md), [milestone plan](docs/milestones.md), and
[development log](docs/development_log.md) for evidence and next steps.
