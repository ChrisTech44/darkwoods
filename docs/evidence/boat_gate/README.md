# Boat / Ranger Gate — verification

F5b completed and published on 17 October 2026 together with the progress-paced
night (no 40:00 gates). Headless results:

| Check | Result |
| --- | --- |
| `python3 tools/verify.py` | 116/116 steps, no errors |
| `field_escapes.gd` | 58 checks, 0 failures |
| `radio_rescue.gd` | 34 checks, 0 failures |
| `woods_playthrough.gd` (all enemies active, input only) | 227 checks, 0 failures |
| `verify_network.py --mode all --players 2` | 6 processes, 361 assertions, 0 failures |

Earlier targeted graphical and four-peer runs by the previous session are
described in the [development log](../../development_log.md). Screenshots are in
[the player guide](../../boat_gate.md). Human pacing, cross-machine Internet and
export platforms remain unverified.
