# Objective scenery independent of nightly routes

19 October 2026. macOS, Godot 4.7.2. Fixes the
[documented inactive-substation defect](../substation_diagnosis/README.md).

Permanent scenery now renders on every Expedition: substation cabinet and both
transformers, relay mast/cabinet, logging machinery, lakeshore shelter, ranger
booth/breaker/signals, boat hull and unlit quarry pyre. Only tonight's routes
permit their existing interactions, component spawns, preparation and extraction.
An inactive ranger barrier is drawn raised and still has no barrier collision.
Inactive boat scenery has no repair pad/status, and inactive machinery has no
painted E instruction. Gate-only power does not light the inactive relay.

The scenery layers retain the existing clearing and sight requirements. A visible
north cabinet face can now anchor its silhouette and flashlight brightness as
well as the south face; this does not reveal hidden caches or actors. Continuously
redrawn machinery layers report empty draws to StandingProps, removing cached
silhouettes once their anchors leave sight. Collision footprints and host-owned
objective state are unchanged.

## Graphical evidence

Command:

```sh
godot --path . --audio-driver Dummy --script res://tests/integration/objective_scenery.gd -- --capture
```

The fixture exercises four **normal van + one secondary** nights, including the
original boat seed 13. It never forces all escapes. AI and the night clock are
frozen, player poses and camera framing are staged; ambient light, sight, weather
and flashlight rules are unaltered. Voice is explicitly off, Dummy audio is used,
and no microphone/network session is started. These are 384×216 viewport images
from actual graphical rendering, not headless render claims or a human playthrough.
All 32 views were visually inspected. Selected captures:

| View | What it checks |
| --- | --- |
| [Boat: power front](boat_power_front.png) | Cabinet and both transformers on an inactive power night; no E power label. |
| [Boat: power north](boat_power_north.png) | The same site from its north approach, using the visible north face. |
| [Signal: relay](signal_relay.png) | Permanent relay mast/cabinet without transmit text. |
| [Signal: logging](signal_logging.png) | Logging shelter/machinery without the boat motor instruction. |
| [Signal: lakeshore](signal_lakeshore.png) | Permanent shelter and racks on an inactive boat night. |
| [Boat: ranger](boat_ranger.png) | Booth/breaker/signals and raised inactive barrier. |
| [Signal: hull](signal_hull.png) | Inactive hull without repair labels or a launch circle. |
| [Boat: pyre](boat_pyre.png) | Unlit inactive pyre; no preparation action or light. |
| [Gate: ranger](gate_ranger.png) | Active gate retains its closed barrier. |
| [Radio: relay](radio_relay.png) | Active relay retains its transmit instruction. |
| [Gate: power front](gate_power_front.png) | Shared substation still supports a gate night. |

[Graphical assertions](capture.log): 97 checks, zero failures. They include actual
prop instances at each site, front/north cabinet approaches, no inactive
interactions, unchanged gate collision eligibility, and removal after leaving
sight. Visual inspection is separate from sprite-instance assertions.

## Regression verification

All commands below exited zero without engine warnings/errors in their final runs:

- Required [import](import.log): `godot --headless --path . --import`.
- Required [startup](startup.log): `godot --headless --path . --quit-after 5`.
- [Objective scenery](objective_scenery.log): 33 checks.
- [Normal-route balance](playtest_balance.log): 23 checks.
- [Radio rescue](radio_rescue.log): 34 checks, diagnostic `--all-escapes`.
- [Boat/gate](field_escapes.log): 58 checks, diagnostic `--all-escapes`.
- [Signal fire](signal_fire.log): 31 checks.
- [Clue rotation](rotation_clues.log): 15 checks.

Integration command pattern:

```sh
godot --headless --path . --audio-driver Dummy --fixed-fps 60 --script res://tests/integration/SUITE.gd
```

Append `-- --all-escapes` only for radio_rescue and field_escapes. The new
objective_scenery headless check is also registered in `tools/verify.py`; the full
broad runner was not run for this increment.

The original clue suite expected a part skyline marker before its delayed cache
spawned. That assertion also failed on isolated unchanged HEAD `237e0de`
([baseline](baseline_clues.log)). Updated the test to require no marker before
spawn and a known marker after reveal; production clue/skyline behavior is
unchanged. Initial sandbox attempts could not write Godot logs/editor settings or
read macOS certificates; required checks were rerun with the necessary access.

Markdown links and `git diff --check` were checked. These results do not establish
Windows/Linux exports, real microphone/listening quality, cross-machine network
rendering, every seed or human gameplay readability.
