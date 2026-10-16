# Forest hunt update evidence

Full `python3 tools/verify.py --graphical` run on macOS arm64 / Godot 4.7.2:
50 steps, seven suites in headless and graphical modes, no engine errors/warnings.
Exact commands and per-step outcomes are in `summary.json`; raw logs retain the
JSON assertions and test_result summaries. Original art hashes are recorded in
`art_sha256.json`; rebuilding all six sheets reproduced identical bytes.

- `woods_*` creature, lighting, landmark, map and result images are placed rule/
  art fixtures, with AI disabled. Creature close-ups offset the native camera.
- `hunt_village.png`, `hunt_bog.png`, `hunt_graveyard.png` are site inspection
  fixtures with the camera zoomed to 0.75 for context. Huts are actually enterable;
  their interior navigation is separately asserted.
- `hunt_witch_windup.png`, `hunt_hex_bolt.png` show a real native-physics witch
  wind-up and moving spell in an isolated encounter, not a composited effect.
- `woods_playthrough_win.png` is the complete seed 42 expedition through ordinary
  input, all five enemies active, using the village well/crypt supplies and
  installing all five parts. No teleports, health/inventory edits or AI disabling.

Eight seeds receive recipe/topology checks; seeds 42 and 2026 also receive native
navigation checks for every item, landmark and clearing's nearest walkable point.
Only seed 42 has a complete active Woods escape route. A route-guided bot is not
proof of human balance across all seeds. No network sessions, exports or other
desktop platforms were tested.
