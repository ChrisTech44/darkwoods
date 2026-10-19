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
