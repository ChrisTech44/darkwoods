# Friends playtest fixes — execution evidence

20 October 2026; macOS Apple M2, Godot 4.7.2, source rules `lnac-net-22`.
[Investigation, implemented rules and unimplemented proposals](../../playtest_followup.md).

## Rendered output

- [Alex's marker before disconnection, seen by Christian](marker_before.png).
- [Alex's marker after recovery, seen by Christian](marker_after.png).
- [John's corrected selector rules](john_selector.png), captured in the actual
  menu without changing saved survivor preferences.
- [Max's existing oversized help panel](max_help_baseline.png), documenting the
  problem for the proposed compact replacement; that replacement is not implemented.

The three world views are real 384×216 renderer captures from separate ENet
clients. They use
normal lighting and route selection, seed 42, frozen enemies, a disabled night
director, staged nearby actors, a supplied objective and a placed marker. Dropped
gear is deliberately staged by disconnecting Alex. No forced all-escape override,
bright-light override or microphone capture is used in these captures. Crowded
pickup/name labels are visible; these are targeted marker checks, not clearance
of every world/HUD overlap or human readability condition.

## Executed gates

| Gate / command | Result |
| --- | --- |
| `godot --headless --path . --import` | Clean final import |
| `godot --headless --path . --quit-after 5` | Clean final startup |
| `godot --headless --path . --audio-driver Dummy --script res://tests/integration/four_survivors.gd` | 190 assertions: halved/deferred damage, grace, once-only settlement, full damage outside the window/after a grab, drain, kits, all typed creature references, copied holds and vault cleanup |
| `python3 tools/verify_reconnect.py --dedicated --players 4 --graphical` | 80 assertions across one authority and four rendered clients |
| `python3 tools/verify_reconnect.py --players 4` | 68 assertions across listen host and three clients |
| `python3 tools/verify_reconnect.py --dedicated --players 1` | 41 assertions, including fully disconnected authority pause/resume and final reservation expiry |
| `python3 tools/verify_dedicated.py --players 4 --mode woods --simultaneous-disconnect` | Production authority plus four clients: 153 assertions; automatic round/lobby lifecycle and simultaneous voluntary departures |
| `python3 tools/verify_network.py --mode woods --players 4` | 428 assertions, including interleaved snapshots, eleven seconds without complete world state while motion remains healthy, prediction, objectives and lifecycle |
| `python3 tools/verify_network.py --mode camp --players 2` | 150 assertions: Quick Camp lifecycle, interleaving/liveness and unknown late-join rejection |
| `godot --headless --path . --audio-driver Dummy --script res://tests/integration/movement_prediction.gd` | 81 assertions |
| `godot --headless --path . --audio-driver Dummy --script res://tests/integration/map_exploration.gd` | 15 assertions |
| `godot --headless --path . --audio-driver Dummy --script res://tests/integration/menu_smoke.gd` | 37 assertions |
| `python3 tools/verify_voice.py` | 24 codec/routing + 8 guest + 13 host assertions; synthetic input only, no microphones |

[Machine-readable results](results.json) and selected [dedicated](dedicated_host.log),
[teammate](teammate.log), [listen](listen_host.log), [empty-round](empty_round.log)
and [ability/cleanup](four_survivors.log) logs preserve these checks.
Raw transient logs remain ignored under `artifacts/playtest_recovery/`.

The recovery fixtures exercise actual ENet disconnection and automatic retry with
new peer IDs. They assert five-minute reservation deadlines, immediate objective
and supply drops, teammate collection, an empty returning belt/inventory, preserved
health/position/kit/cooldowns, reliable removal without world snapshots, rejection
of deliberately delayed pre-departure snapshots, cleared tethers, updated membership,
a fifteen-second silent-input watchdog and recovery after that watchdog. Other
idle clients remain connected throughout; no keypress is required to stay online.
The last reservation's expiry clock is deliberately advanced rather than waiting
five real minutes. AI is frozen; this is not a natural round or balance playtest.

Existing general network/dedicated suites also stage objectives and speed up
countdowns. The general network suite forces all escapes to exercise every route;
that diagnostic override is not used by the marker captures or recovery fixtures.

## Limits and failures resolved during implementation

An initial sandboxed import printed macOS certificate/editor-settings permission
errors; the final import/startup ran with ordinary local Godot access and printed
no engine errors/warnings. Early tests caught missing tether metadata access,
cleanup on an already closed transport and an incorrect test-only objective setup;
these were corrected. The withheld-world test then reproduced a delayed snapshot
restoring a cleared tether; the final reliable departure now rejects all snapshots
captured before that departure. Final selected runs pass without errors/warnings.

This is a targeted regression set, not the complete `tools/verify.py` suite.
It does not reproduce the original Internet failure or prove NAT/VPN/Wi-Fi stability,
real-microphone/listening behavior, Windows/Linux packaging, an exported rules22
PCK, production deployment, five-minute wall-clock endurance or long-term balance.
The prior rules21 bundle remains historical; update both server and clients and
rebuild packages before distribution. No running server was restarted.
