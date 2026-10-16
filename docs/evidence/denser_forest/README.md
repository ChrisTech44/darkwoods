# Survivor rendering and denser forest evidence

Full headless verification is recorded in `summary.json`; all steps passed with
zero errors/warnings. Required imports/startup, syntax, offline win/loss, denser
expedition escape, navigation, sight, audio and lifecycle checks ran.

Commands: `python3 tools/verify.py`; graphical `player_render.gd` with Dummy audio
(13 assertions); graphical `content_expansion.gd -- --capture` (343 assertions);
graphical `surround_world.gd -- --capture` (113 assertions), all zero failures.
Logs and selected unedited engine PNGs are preserved here. The player-render
images are isolated transparent SubViewport captures of actual survivor drawing.
Biomes/monster close-ups are brightened inspection fixtures with sight masking
and AI disabled; the belt image uses ordinary lighting. The full map is an
inspection atlas of the current Night 42, not the explored-only player map.

The active expedition escape log uses ordinary input against all 49 enemies;
no disabled AI, rule edits or player teleports. Human difficulty tuning,
Windows/Linux, exports and Internet/network acceptance remain unverified at
this increment. The next increment adds networking separately.
