# Hiding, doors and knock-overs evidence (overhaul F3b)

macOS arm64 / Godot 4.7.2, 16 October 2026. Network rules version `lnac-net-7`.

| Command | Result |
| --- | --- |
| `python3 tools/verify.py` | 87/87 steps passed, no errors or warnings ([summary](verify_summary.json)) |
| `godot --audio-driver Dummy --path . --fixed-fps 60 --disable-vsync --script res://tests/integration/chase_props.gd -- --capture` | 36 assertions passed (33 headless, see [log](chase_props.log)) |
| `python3 tools/verify_network.py --mode all --players 2` | 6 processes / 269 assertions passed ([summary](summary_all_2.json)) |
| `python3 tools/verify_network.py --mode all --players 4` | 8 processes / 455 assertions passed ([summary](summary_all_4.json)) |

| Hidden under a bunk | Door slammed (beam blocked) | Woodpile knocked over |
| --- | --- | --- |
| ![Hidden survivor with breath HUD](props_hidden.png) | ![Closed cabin door blocking the flashlight](props_door.png) | ![Fallen woodpile blocking a lane](props_knockover.png) |

Normal Dusk fog lighting. The fallen woodpile is readable in the beam but
low-contrast; it is a candidate for the planned art revamp. Not verified: human
feel of breath and door timings, graphical network windows, other platforms.
