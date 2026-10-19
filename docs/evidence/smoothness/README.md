# Gameplay smoothness evidence — 18 October 2026

## Rendering increment

Matched 18-leg sequential graphical client probes, macOS M2 Godot 4.7.2,
768×432, normal Woods seed 1788400090/fog, live enemies and normal lighting.
Separate local source dedicated server, protocol 17. Voice/microphones disabled.
Both clients used identical temporary wrappers to profile process/draw calls;
these wrappers are not shipped. The baseline uses the preceding committed
rendering code. No forced parts, escapes, teleports, frozen enemies or altered
lighting. An earlier short baseline that lost its server was discarded.

| Measurement | Before | After |
| --- | ---: | ---: |
| Mean frame interval | 50.21ms | 8.51ms |
| Average FPS (1000 / mean interval) | 19.9 | 117.6 |
| 99th percentile frame interval | 56.80ms | 13.59ms |
| Maximum frame interval | 75.92ms | 33.98ms |
| Median visible movement response | 157.6ms | 114.7ms |

[Raw metrics](render_metrics.json), [inspected graphical capture](render.png).
The capture retains fog, dark forest, region/part labels and HUD. Readability
redesign is outside this change. This is a local measured scene, not a promise
of 118 FPS on every machine or with four graphical clients. RTT also improved
because the slow client processed network events late; this does not measure
an Internet-path improvement. Input still waits for the authority in this
increment; prediction follows separately.

ForestSite and pickup redraws dominated baseline script work. Unchanged world
replication now preserves cached drawings, while changed used/locked/present,
kind or position state invalidates the affected art and neighbouring pile labels.
Calling-card fades redraw only while changing, and the immutable seeded hook
location is cached. Game rules, clue discovery and authority remain unchanged.

Checks: graphical render_replication 8/8; real ENet Camp/Woods two-player suites
379 assertions; required headless import/startup and diff checks clean. The
render fixture freezes enemies and stages two pickups to test pile invalidation;
it is not the performance run or screenshot. No broad-suite, Windows or microphone
acceptance claim.

## Prediction and interpolation increment (rules lnac-net-18)

Final actual graphical Mac client → Genesect Linux Snap Mono 4.7.2 source server,
24 one-second input legs (~24s measured), normal Woods seed 1788400090/fog,
live AI and ordinary up/down walking. No profile wrappers, forced parts/escape,
teleports, frozen enemies or lighting changes. Voice/microphones off. Server ran
on spare UDP 28335 in games/darkwoods/artifacts/smoothness18, imported first and
self-terminated; production checkout 5debe70 and regular UDP 27840 were unchanged.

| Measurement | Final run |
| --- | ---: |
| Mean frame interval / average FPS | 8.49ms / 117.7 |
| 99th percentile / maximum frame | 13.66ms / 31.88ms |
| Visible >2px input response median / maximum | 26.38ms / 32.27ms |
| Response timeouts | 0/24 |
| RTT median / mean / maximum | 66ms / 92.88ms / 259ms |
| Player packet gap median / 99th / maximum | 33.33ms / 50.00ms / 123.24ms |
| Largest visible player frame step | 1.49px |
| Largest reconciliation anchor error | 7.00px |
| Server mean / maximum physics interval | 16.67ms / 41.09ms |
| Server maximum measured Net tick | 2.24ms |

[Raw final client/server metrics](prediction_metrics.json),
[inspected graphical capture](prediction.png). Input response includes the time
needed to travel two pixels; it is not physical-keyboard/monitor latency. RTT did
not vanish: local presentation responds before it. Earlier separate production
playback reported ~22 FPS and ~208ms median response; these are different runs,
not a controlled same-time network comparison. The matched rendering comparison
above establishes that improvement independently. An initial prediction trial
also measured 119.4 FPS and 30.35ms median response, but final values above include
predicted animation and authoritative discontinuity counters.

The owner reuses authoritative collision/movement code in physics frames with a
shadow state; it never sends positions or simulates outcomes. The authority sends
only applied-input acknowledgements. At most 250ms of recent inputs replay; stale
prediction freezes rather than inventing seconds of travel. Ordinary corrections
ease with a 180px/s limit. Server-side discontinuity counters preserve real warps
without mistaking normal travel hidden by a network gap for one. Small relocations
below the authority detector's 96px threshold ease as corrections. Status/effect
expiry still comes from the authority; prediction does not guess releases.
Other players/enemies interpolate 80ms behind server time, extrapolate at most
50ms, then hold. Recovery rendering is capped at max(240px/s, 1.5×latest speed).
This trades a short remote presentation delay for steadier motion. Interactions,
damage and clue discovery remain host-owned and can still wait for the network.
Multi-second external stalls are not repaired by these changes.

Physics fixture: 74 assertions covering shared sprint/diagonal/collision slides,
heavy/assisted/Jock/wounded/exhausted, knock, hold/vault/hide/down/curses,
no gameplay-state/noise/blood mutations, immediate movement/animation,
acknowledgement trimming, bounded outages/history, correction limits, real warps,
remote jitter/order/extrapolation/recovery, packet size and invalid state.
Real-peer Camp/Woods tests additionally pause BOTH authority streams for two
seconds while directions continue, verify bounded freeze/recovery and force the
world-before-motion arrival race. Ordinary authority, forgery, pickup, extraction,
restart and departure checks remain in the same suites. These fixtures freeze AI,
stage host positions and enable all escape routes; performance captures do not.

Offline authoritative regressions: chase toolkit 29, chase props 46, survivor
abilities 33, monster effects 147, field escapes 58, graphical redraw fixture 8;
all clean. Linux source server and Mac graphical client imports/startup/error
scans clean. No broad suite, Windows, exported-client, real voice or long-session
Internet acceptance claim. The known simultaneous ENet-close error is separate;
ordinary dedicated tests stagger departures.

Final [listen-peer report](listen_peer_summary.json): **393 assertions**, all
processes clean. A separate assembled server checkout with the final dedicated
features and protocol also passed [four-main-client source checks](dedicated_source_four.json),
**69 assertions**; headless logical replicas suppress drawing but retain physics.
Portable-pack acceptance is recorded on the dedicated branch after merging.

## Dedicated branch/package acceptance

The merged dedicated branch passed [local exported PCK + four main clients](dedicated_pack_four.json),
69 assertions, plus the four source-launcher Python regressions and required
import/startup/export/error checks. The same runtime PCK then ran under Linux
Snap Godot 4.7.2 Mono on Genesect spare UDP28336 with four macOS main source
clients: [all 69 real-network assertions passed](linux_pack_four.json), no engine
warnings/errors, server exit0. The external test driver accepts LNAC_TEST_HOST
(default loopback); it is not included in the exported game. Extraction, results,
second-round readiness/reset, objective drops and empty-server cleanup passed.
These lifecycle fixtures stage authority positions, enable all escapes and freeze
AI; headless clients hide scenery. Use the ordinary graphical run above for
smoothness evidence, not this staged lifecycle test. Voice/microphones off.

This establishes Linux PCK operation with that installed engine, not a bundled
Linux executable, Windows, graphical exported clients or long-session acceptance.
Regular checkout5debe70/UDP27840 was not updated/restarted. Server-only runtime,
launcher and packaging remain on headless-server; main has gameplay/client changes.
Update both branches' copies and restart the old server before joining protocol18.
