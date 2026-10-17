# README screenshots

Unedited Godot viewport captures used by the main README, retaken on
17 October 2026 after the SpriteCook art passes (again after the fourth art batch). Each file is copied from the
`artifacts/verification/` (or `artifacts/network/`) capture named below,
produced by `python3 tools/verify.py --graphical` and
`python3 tools/verify_network.py --mode all --players 2`.

| File | Source capture | Test |
| --- | --- | --- |
| `treeline_north.png`, `treeline_south.png` | `treeline_after_north.png`, `treeline_after_south.png` | `treeline.gd` |
| `menu_defaults.png` | `menu_defaults.png` | `menu_defaults.gd` |
| `survivor_selection.png` | `survivor_selection.png` | `content_expansion.gd` |
| `nav_signpost.png` | `nav_signpost.png` | `navigation_aids.gd` |
| `lobby.png` | `network/lobby_camp_2.png` | `network_peer.gd` |
| `audio_pause_mixer.png` | `audio_pause_mixer.png` | `audio_polish.gd` |
| `full_map.png` | `surround_overview.png` | `surround_world.gd` |
| `campsite.png` | `upgrade_campsite.png` | `camp_upgrade.gd` |
| `mess_hall.png` | `upgrade_mess_hall.png` | `camp_upgrade.gd` |
| `woods_light_on.png`, `woods_field_notes.png` | same names | `woods_replay.gd` |
| `woods_<creature>.png` | same names | `forest_hunt.gd` |
| `monster_<species>.png` | same names | `content_expansion.gd` |
| `landmark_<region>.png` | same names | `surround_world.gd` |
| `item_belt.png` | `item_belt.png` | `content_expansion.gd` |
| `woods_loading.png` | `woods_loading.png` | `woods_replay.gd` |
| `woods_playthrough_win.png` | `woods_playthrough_win.png` | `woods_playthrough.gd` |
| `signal_fire.png`, `groundskeeper_snare.png`, `scout_mark.png`, `stalkers_gift.png`, `lost_camper.png`, `van_finale.png`, `results_score.png`, `camp_journal.png` | `artifacts/showcase/` | `tools/capture_showcase.gd` |

Camp shots use Quick Camp with controlled player placements and the stalker
paused for inspection. Creature portraits disable AI. Landmark close-ups
(`landmark_*`) hide the HUD, raise ambient light and switch off the sight mask
so the art is readable; normal nights are much darker. The extraction result
comes from a complete automated expedition with all enemies active.

After the playtest feedback round (17 October, later): `boat_launch.png`,
`lakeshore_boathouse.png` and `lake_thing.png` (from `field_escapes.gd --capture`,
`artifacts/verification/rescue_boat.png`, `rescue_boathouse.png`,
`rescue_lake_thing.png`) show the new lake water; `groundskeeper_snare.png`
(reframed showcase) shows the Groundskeeper facing his direction of travel;
`lobby.png` shows the lobby voice meters. These frames include the new health bar.

Older captures cited by the development log stay in `../evidence/` unchanged.

The treeline captures use normal night exposure and weather, with controlled
placements and AI paused for inspection. They do not raise ambient light or
disable the sight mask. See `../evidence/forest_treeline` for matched baseline
views and strict sight/shadow pixel controls.
