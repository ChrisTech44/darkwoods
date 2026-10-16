# Woods expedition evidence

Final `python3 tools/verify.py --graphical` run, macOS arm64 / Godot 4.7.2.
`summary.json` contains executed commands, exit status, errors and warnings.
Raw per-step logs include JSON assertions and one test_result per suite.

- `menu.png`, `controls.png`, `woods_loading.png`: real rendered UI.
- `woods_light_on.png`, `woods_light_off.png`: matched local-light probe.
- `woods_werewolf.png`, `woods_bigfoot.png`, `woods_lantern_moth.png`: isolated
  close art fixtures; enemies disabled and camera offset for inspection.
- `woods_gate.png`, `woods_landmark_*.png`, `woods_field_notes.png`,
  `woods_results.png`: placed art/rule fixtures, not a complete traversal.
- `woods_playthrough_win.png`: full seed 42 expedition through movement/input,
  all enemies active, no teleport/health/inventory edits or AI disabling.

Eight seeds receive topology/recipe checks; seeds 42 and 2026 also receive native
navigation checks for every clearing, item and landmark. Only seed 42 has a
complete active Woods escape test. The bot uses native paths as a route guide;
human balance, connected multiplayer and other desktop platforms are unverified.
