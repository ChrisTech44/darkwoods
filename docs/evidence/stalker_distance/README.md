# Distance-gated stalking — 18 October 2026

The Stalker now approaches distant/occluded targets without advancing the lunge
timer. Only being within 260px with clear sight accumulates stalking time. Lost
distance/sight pauses, rather than resets, the accumulated time. Approach speed
is 88px/s (ordinary survivor walk 70, sprint 110); nearby follow speed is 78px/s,
aiming 130px behind the target rather than the previous 190px. Calling-card
placement range remains independently fixed at 230px, with existing timers.

These remain Expedition/Nightfall/PATROL traits; ordinary detection/chase, beam
fading and grab/hook rules are unchanged. Target selection still follows the
existing favorite-survivor logic. This does not add target rotation or new cards.

Godot 4.7.2 on macOS Apple M2. Exact reproduction commands, from project root:

```sh
godot --headless --path . --import
godot --headless --path . --quit-after 5
godot --headless --path . --audio-driver Dummy --fixed-fps 60 --disable-vsync --script res://tests/integration/stalker_distance.gd
godot --path . --audio-driver Dummy --fixed-fps 60 --disable-vsync --script res://tests/integration/stalker_distance.gd -- --capture
godot --headless --path . --audio-driver Dummy --fixed-fps 60 --disable-vsync --script res://tests/integration/monster_revamp.gd
godot --headless --path . --audio-driver Dummy --fixed-fps 60 --disable-vsync --script res://tests/integration/chase_toolkit.gd
godot --headless --path . --audio-driver Dummy --fixed-fps 60 --disable-vsync --script res://tests/integration/woods_playthrough.gd
git diff --check
```

All final commands exited 0 with no engine errors/warnings:

| Check | Evidence |
| --- | --- |
| Import/startup | [Import](import.log), [startup](startup.log). |
| Distance/occlusion/navigation | [15 assertions, zero failures](headless.log). |
| Graphical distance/fade | [17 assertions, zero failures](graphical.log); includes two PNG writes. |
| Existing monster behaviors | [140 assertions, zero failures](monster_revamp.log). |
| Chase toolkit | [29 assertions, zero failures](chase_toolkit.log). |
| Expedition input playthrough | [227 assertions, zero failures](woods_playthrough.log), including escape with all enemies active. |

The controlled distance fixture uses seed 42, a straight north-ring road and a
walking player with other enemies disabled. Real collision/navigation closes a
350px initial gap to ~218px after ten simulated seconds, then ~154px after twenty.
The timer remains paused for a distant target and for a nearby target across a
wall, advances nearby, and eventually transitions to CHASE. Tests also cover
Dusk/direct chase exclusions, beam fade and unchanged calling-card reach.

The two actual viewport captures were opened and visually inspected, with normal
fog-night lighting and sight. [Nearby shadow](nearby_shadow.png) shows the dark
silhouette near the left edge; [beam fade](beam_fade.png) shows the same killer
faded after the fixture turns the player's light toward him. These are staged
snapshots, not a human encounter/pacing acceptance test. The fixture explicitly
redraws the disabled killer after changing its staged fade state.

An initial test revision failed GDScript type inference for a fixture variable;
it was corrected before the passing runs. The first movement/camera inspection
used a 150px follow goal; the final implementation/tests use 130px to improve
framing. The broad runner now includes the new distance suite and requires its
test summary; Python syntax was checked, but the complete runner was not rerun.
No real microphones, cross-machine multiplayer, exports or human balance tests
were used. All listed suites passed at the final 130px setting, including a repeated
chase/playthrough check after the final tuning adjustment. No planning documents
were changed.
