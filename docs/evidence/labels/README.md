# Building names, place titles, short names and skyline: evidence

18 October 2026, Godot 4.7.2, macOS Apple M2, 384×216. Staged captures:
seed 42, enemies frozen, night progression stopped; `capture_world_review.gd`
forces all escapes (diagnostic) and its `inspection_*` view disables sight and
brightens ambient light on purpose. The fixture teleports between placements,
so a place title from a previous placement can still be fading in a shot
(e.g. "RANGER ROAD AND BRIDGE" in the crowded-bearings image).

| Image | Shows |
| --- | --- |
| [building_cabin_224](building_cabin_224.png), [bunkhouse](building_bunkhouse_816.png), [mess](building_mess_832.png), [boat](building_boat_1200.png) | Normal lighting on the door approach: the building name on its plaque, readable, with `OUTSIDE …` on the location line; `CAMP BOATHOUSE` |
| [door_plaque](door_plaque.png) | Same at Maintenance (captured during the Dusk title) |
| [place_title](place_title.png) | Entering Maintenance: `MAINTENANCE / CAMP BUILDING` |
| [inspection_workshop](inspection_workshop.png) | Bright inspection view: the roof no longer carries a name; the plaque sits below the eave |
| [signpost](signpost.png) | Signpost boards with `SUBSTATION`, `VILLAGE`; skyline names from full names |
| [crowded_bearings](crowded_bearings.png) | Staged help ping + pin on one bearing: one merged marker `HELP … +2` with a backed label |

Commands: `godot --path . --audio-driver Dummy --script res://tools/capture_notebook.gd -- --all-escapes`
and `godot --path . --audio-driver Dummy --script res://tools/capture_world_review.gd`;
both exited 0 with all PNGs written. Images were opened and inspected.
Not established: four-peer crowding in live play, other window sizes, human
reading speed.
