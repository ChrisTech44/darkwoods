# Development log

## 2026-10-15 — First major update README and ongoing GitHub publishing rule

**Requested scope:** keep GitHub continuously updated and explain the current
game, rules and screenshots in the README. Added a root `AGENTS.md` workflow and
an explicit publishing rule to the authoritative brief: after each coherent,
verified increment, update documentation/logs, commit, push the current branch
to origin, and confirm the remote commit. Routine pushes are user-authorized;
force pushes, unrelated changes and publishing credentials remain excluded.

Reworked README into a player introduction with source setup, both modes,
step-by-step escape/boarding rules, controls, survival supplies, damage/revive,
weather, all four threat types, seeds/replay, roadmap and verification links.
Ten actual engine screenshots show the menu, campsite, lodge, dark woods, field
notes, three cryptids, loading card and successful extraction. Reused committed
woods evidence and preserved two unedited camp tour captures under
`docs/screenshots`, with provenance. Clearly labeled offline-only availability,
fixture creature shots, pending networking/exports and platform/balance limits.

**Verification:** checked gameplay claims against configuration, round recipe,
van/supply/player/AI scripts and existing evidence. All 20 local Markdown links
resolve; all 10 embedded images are valid 384×216 PNGs. Copied camp shots match
the previous verified graphical captures byte-for-byte. `git diff --check`
exited 0. `godot --headless --path . --import` and
`godot --headless --path . --quit-after 5` each exited 0, with no engine errors or
warnings. No gameplay code changed, so the existing 45-step graphical acceptance
report remains the gameplay evidence; full gameplay suites were not rerun for
this documentation-only increment.

**Publishing:** `git fetch origin` exited 0. Before this increment, `main` was
four verified game commits ahead of `origin/main`, with no remote-only commits.
This delivery publishes those M0/M1/woods commits together with the README and
workflow rule using a normal push, followed by remote/local commit comparison.

## 2026-10-15 — Requested woods expeditions, cryptids, replayability and UI

**Selected scope:** the user requested a better loading/menu experience, a much
larger ominous woods section, detailed cryptids, survival supplies and harder,
maze-like objectives. This explicitly authorizes this portion of M5 ahead of M2;
the authoritative brief and supplied Word file remain intact. Implemented in
passes: UI/run selection; seeded topology/objectives/supplies; creature behavior;
headless rule checks; complete active expedition; rendered review and corrections.
The offline round remains runnable, with Quick Camp retaining the shorter M1 loop.

**Implemented:** full world bounds 3456×1920 (4.5 times the previous camp bounds),
including a finite 1600×1600 woods maze with 100 connected clearings, loops, dead
ends and six landmarks: split stump, hunter's blind, hollow cave, fallen tower,
crooked shrine and scrap cache. Added original roots, mushrooms, trail markers,
ruin details and dense tree walls. Shared geometry drives collision, occlusion
and native navigation. The woods chart reveals explored trails instead of giving
away the entire maze; notes provide item/landmark clues.

Woods Expedition needs five components: battery/fuel/key and two drawn from
belt/fuse/tire/spark plug. Battery/key locations vary among camp rooms. Boltcutters
in Maintenance open three randomized woods caches. Reusable cutters and all
items require normal availability/proximity/clear-access checks. Supplies include
9-second flares, spare torch batteries (+70s up to 90s), stamina-restoring rations,
and medkits that shorten completed teammate revives to 1.2s. Q/R/C use flare/
battery/food; F toggles light; Tab opens notes. Torches deplete while lit in the
woods. Pause freezes drain, flare lifetime, monsters and round timers.

Two of three cryptid species roam each expedition alongside the camp stalker.
Original 64×64 directional walking sheets depict werewolf, Bigfoot and lantern
moth. Wolves alternate brief fast charges and slower recovery; Bigfoot hears
farther; moths sense lit survivors and nearby visible flares, ignoring distant
survivors in darkness. Flares repel the stalker/wolf/Bigfoot and attract moths.
All inherit sensed-memory AI and native navigation; hidden player positions do
not become chase destinations. Camp patrol order/start, trail layout, loot,
required extra parts, roster and weather vary by seed. Fog reduces beam/sight;
rain reduces hearing. No audio was added; HOWL/alert cues are visual.

The new menu has layered animated original forest art, mode and optional seed
selection, and a consistent olive/cream theme shared by controls, notes and
results. A loading card renders before world preparation, with an activity bar
rather than a fabricated completion percentage. Results offer another night,
retry same seed, or menu. Retry recreates fresh actors/items with the same plan.

**Incremental verification:** new-mode startup exited 0, legacy headless mechanics
and complete camp win/loss/restart remained passing. Seed/rule checks initially
passed 191 assertions; subsequent coverage adds weather perception, medkit
completion/interruption and native navigation to all 100 clearings in two seeds.
A complete active expedition passes using ordinary movement/interact/supply
input, collecting all five parts, repairing, boarding and escaping. It covers
about 14,700px and 52 clearings in seed 42. The bot uses native paths as an omniscient
route guide; this is automated playability evidence, not proof of human balance.

**Failures corrected:** standalone parse checks could not resolve the autoload's
global identifier, so scripts obtain Session through the scene tree. Tests now
wait for the actual loaded scene/navigation readiness instead of fixed frame
counts. Initial threaded loading produced leaked RefCounted warnings on teardown;
isolated repeat transitions reproduced them, and synchronous staged preparation
removed them. A moth's visual flare response incorrectly used its shorter hearing
radius; corrected to a line-of-sight light stimulus. Pause measurement was moved
after the input boundary. Medkit progress now uses the correct hold duration.
An empty torch cannot be toggled on without a battery.

Early expedition bots were caught; reordered camp preparation and timed flares/
sprint more promptly, without weakening production damage/AI/speeds. A route
helper approximated every diagonal as 45 degrees and collided with a tree; input
strengths now follow native path segments correctly. The bot also stopped
repeatedly pressing F on a depleted torch. Graphical tests exposed a clipped
field guide and a null scene during the loading capture; compacted the guide and
waited for the LoadingScreen node. Rendered review moved the woods warning sign
inside the visible approach and composed close creature fixtures below the HUD.

**Final verification:** `python3 tools/verify.py --graphical` exited **0**.
Import, startup, every GDScript parse, and six suites in both headless and actual
graphical modes passed with **zero engine errors or warnings**. `git diff --check`
exited 0. Original cryptid rebuild via `python3 tools/build_cryptids.py` exited 0;
SHA-256 comparison confirmed all three sheets reproduced byte-for-byte.

| Suite | Headless assertions | Graphical assertions | Failures |
| --- | ---: | ---: | ---: |
| Menu/input | 37 | 39 | 0 |
| Offline rules | 60 | 66 | 0 |
| Quick Camp complete rounds | 108 | 113 | 0 |
| Camp layout/boarding | 31 | 44 | 0 |
| Woods seeds/rules/navigation/art | 201 | 214 | 0 |
| Active Woods expedition | 172 | 173 | 0 |

Opened and inspected final menu, full field guide, loading card, woods gate,
matched light on/off, all three cryptids, three ruins, field notes, loss results
and the active expedition's escape result. The matched woods probe measured
luminance **0.394 lit / 0.003 unlit**; the localized-light/darkness
assertion passed. Close cryptid art shots deliberately offset the native camera
for composition; rule/art fixtures are distinguished from the active expedition.
Final logs, commands/report and PNGs: [evidence/woods_replay](evidence/woods_replay/summary.json).

One final graphical expedition exceeded the original 60s test timeout while
returning with all five parts, with no engine errors. Increased only that long
rendered test's timeout to 120s; the subsequent complete verification passed.

**Limits:** macOS arm64 / Godot 4.7.2 only. No connected multiplayer, exports,
Windows/Linux execution or human real-time balance session was performed.
Teammate/medkit/boarding checks are local fixtures; they do not establish co-op.
Networking remains M2. This pass supplies replayable offline mechanics rather
than claiming the eventual 15–25 minute co-op balance or every possible seed tested.

## 2026-10-15 — M1 follow-up: van boarding and requested visual expansion

**Selected scope:** repair the confusing escape flow, then apply the user's
explicitly requested graphics/map/lighting improvements. This authorizes this
visual portion of polish ahead of M2; no networking milestone is claimed.

**Boarding:** the old implementation had no enter/aboard state and only checked
distance at departure, leaving waiting players vulnerable. The driver now boards
automatically after the start hold completes. Other living survivors can press E
at either side or rear door during an eight-second countdown. Proximity and clear
access are validated. BOARDED survivors are visibly seated (passenger pixels in
the van), cannot walk out, and cannot be downed. HUD says YOU ARE ABOARD and shows
the passenger count. Only recorded passengers extract; nearby unboarded players
are left behind. Outcomes include the local player's actual status.

**World/art:** expanded from 768×480 to 1536×960 (four times the area), with ten
authored buildings: bunk cabins, storage, larger bunkhouse, maintenance workshop,
mess hall, ranger lodge, bathhouse, infirmary and boathouse. Added paths, dense
pine/birch woods, undergrowth, lakeshore/dock and detailed campsite props. Building
interiors have floor materials, windows, beds, offices, shelving, workbenches,
kitchen/dining tables, showers/sink, medical beds and canoe storage. Larger lodgings
have interior partitions; roofs fade away on entry and return outside.

Created original directional camper and stalker sheets with walking frames,
hiking clothing/pack/rolled mat and a distinct hooded stalker with logging hook.
Original terrain/tree art is reproducible via `python3 tools/build_pixel_art.py`
(exit 0, Python standard library only). No external assets/plugins were obtained.
Rebuilding again and comparing SHA-256 values confirmed all nine PNG assets are
byte-for-byte deterministic.
The staged whitespace check identified trailing spaces in native engine progress
output. Extended the existing evidence-log-only Git attribute to preserve those
raw lines; source and document whitespace checks remain enabled.
The existing decorative menu backdrop is retained; the gameplay visuals are
upgraded. Provenance/layout: [assets/README.md](../assets/README.md).

Replaced the darkness shader with native CanvasModulate, PointLight2D beams and
LightOccluder2D walls/trunks. Unlit woods are nearly black, with small local player
glow; flashlights, warm lamps, campfire and van headlights illuminate local areas.
Added a Tab field map with building footprints, supply markers, van and player
position, and location labels so the larger dark map remains navigable.

**Verification:** `python3 tools/verify.py --graphical` final exit **0**; import,
startup, every script's parse check, and four suites in both modes passed with
no engine errors or warnings. `git diff --check` exited 0.

After the deterministic art rebuild, `godot --headless --path . --import`,
`godot --headless --path . --quit-after 5`, and direct gameplay startup with
`--scene res://scenes/world/forest_level.tscn --quit-after 5` each exited 0,
without engine errors or warnings.

| Suite | Headless assertions | Graphical assertions | Failures |
| --- | ---: | ---: | ---: |
| Menu/input bindings | 37 | 39 | 0 |
| Movement, AI, objectives, driver boarding | 60 | 66 | 0 |
| Larger-camp input-only win/loss/restart | 108 | 113 | 0 |
| Layout, roof, boarding, and visual checks | 31 | 44 | 0 |

The full playthrough traverses the relocated objective buildings with collision,
normal pickup/delivery/start controls, an active killer and default rules. Its
native-path helper waits for navigation readiness after scene reload. Additional
fixtures verify all ten entrances and three objective positions are reachable,
two survivors board exactly once and safely extract, downed/distant boarding is
rejected, and a nearby third survivor who never boards is left behind.

The real graphical tour's matched probe measured rendered luminance about **0.292
with the flashlight / 0.010 without it** at one unlit woodland sample. Both assertions
passed. Opened and inspected the campsite, lodge, workshop, bathhouse, mess hall,
shore, characters, field map, boarding, and on/off screenshots. Final snapshot:
[evidence/camp_upgrade](evidence/camp_upgrade/summary.json).

**Failures corrected:** old escape-zone tests were adapted to an explicitly empty
van fixture after automatic driver entry changed the rule. Old walking waypoints
targeted removed supply locations; the input test now traverses the authored new
layout via native paths. Initial/reloaded large-map navigation was not ready after
a fixed few frames; bounded readiness checks resolved the zero-path test failures.
Visual QA caught actors being drawn below interior floors; moved map floors below
the Y-sorted actors. Reduced flashlight overexposure, refined wood/cool bathhouse
lighting, and shortened field-map text to remove HUD overlap. Final checks passed.

**Limits:** executed on macOS arm64 / Godot 4.7.2. No network sessions, exported
packages or other desktop platforms tested. Multi-survivor assertions use local
fixtures and do not imply connected co-op. A human real-time playtest of the
expanded layout remains unrecorded. Restart and menu return remain runnable.

## 2026-10-15 — M1 pass 3: stalker, consequences, and complete rounds

**Implemented:** killer PATROL/INVESTIGATE/CHASE/SEARCH, wall-occluded sight,
nearby noise hearing, per-target sensed memory with decay, target-loss search,
navigation through cabin doors, and route recomputation/stuck recovery. Replaced
the initial grid mesh with a native NavigationServer2D bake that includes body
clearance around the shared obstacle list and van. Added attack cooldown,
down/second-hit elimination, timed teammate revive, interrupted/distant revive
rejection, revive grace, bleed-out, all-dead defeat, and per-player left-behind
status when the van departs without them. Solo has no self-revive.

Added a local night shader and directional flashlight, inventory toggle, visual
footstep/alert cues, and pause that freezes actors and round timers. Threat hints
have their own HUD line to avoid clipping behind contextual messages. All art is
original geometric placeholder drawing; no downloaded assets or plugins.

**Commands/results:** `python3 tools/verify.py --graphical` final exit **0**.
It ran engine version, `--headless --path . --import`, five-frame startup,
individual `--check-only` parses for every GDScript, and the three suites in both
headless and real graphical modes. Every step exited 0; no engine errors or
warnings. `git diff --check` also exited 0.

The first staged whitespace check exited 2 on native Godot logs' trailing empty
lines. Added an evidence-log attribute allowing that format without modifying
the captured output; source/document whitespace checks remain enabled.

| Suite | Headless assertions | Graphical assertions | Failures |
| --- | ---: | ---: | ---: |
| Menu/input bindings | 37 | 39 | 0 |
| Offline physics/rule fixtures | 58 | 64 | 0 |
| Complete input playthrough | 50 | 53 | 0 |

The complete playthrough boots via Play Solo, walks into all three cabins with
normal collision/input, collects and delivers components using E, uses sprint to
evade a sensed chase, starts the van, waits for extraction, wins, restarts using
the result button, walks onto the patrol route for a real loss, and returns to
the menu. Default rules and killer AI remain active throughout. No teleports,
inventory/health edits, or AI disabling occur in that suite. Logs record reached
waypoints, killer states, win/loss, and assertions. The separate mechanics suite
explicitly uses fixtures to isolate validation, navigation, teammate revive,
countdown pause, and leaving the extraction area. Those fixtures are not co-op.

**Failures resolved during this pass:** one graphical run timed out (exit 124)
before its first capture. Capture now explicitly forces rendering rather than
waiting indefinitely for `frame_post_draw`; fixed-step test runs also disable
VSync. Subsequent full graphical runs completed. The initial full walking route
ran into the van (valid collision); waypoints were corrected to go around it and
the trail trees. An all-walking return was caught before departure; the test now
uses ordinary sprint input when chased, and the complete round wins. Production
speeds, damage, AI, and timers were not weakened to make that route pass.

**Evidence:** final report, all raw per-step logs, and viewport PNGs are preserved
in [evidence/m1](evidence/m1/summary.json). Opened and inspected campsite, cabin,
chase, downed, countdown, win/loss, and full-playthrough screenshots. The final
[input-only escape](evidence/m1/playthrough_win.png),
[input-only defeat](evidence/m1/playthrough_loss.png), and
[chase](evidence/m1/chase.png) show readable prompts and lighting at 384×216.

**Status/limits:** M1's offline implementation and automated acceptance pass on
macOS arm64 / Godot 4.7.2. Human playtesting at normal speed remains unrecorded;
the brief's human-play gate is not claimed as executed. Teammate revive is fixture
verified until M2 supplies actual connected humans. No multiplayer, exports,
Windows/Linux, or other macOS architectures were tested. No technical blocker
remains for a human local smoke test; M2 is the next implementation milestone.
The project remains runnable through the menu and `python3 tools/run_game.py`.

## 2026-10-15 — M1 pass 2: supplies, escape, and replay

Added three original component pickups in the three accessible cabins, inventory,
authority-side proximity/availability/line-of-sight validation, rear-of-van
delivery, two-second hold to start, five-second departure countdown, per-player
escape status, results, and scene-reload restart. Interrupted holds reset progress.
The van leaves after countdown; at least one living survivor in range wins.
Also corrected the stamina bar's default theme minimum height.

`python3 tools/verify.py --graphical` exited 0 after an explicit WeakRef type fix
in the test script (the previous parse-only check correctly failed on inference).
Import/startup/all parses, menu, movement, pickup/delivery/start/countdown/escape,
and restart passed without engine errors or warnings. Opened and inspected the
countdown and win screenshots. Snapshot:
[m1_objective](evidence/m1_objective/summary.json).
These objective tests use explicit proximity fixtures, not a human playthrough.
Killer, revive/death, night visibility, and complete traversal are next.

## 2026-10-15 — M1 pass 1: walking in camp

Continued into M1 at the user's instruction. Selected movement/collision as the
first coherent increment: Play Solo, ForestLevel, original fixed map, cabin doors,
native collision/navigation mesh, Player, camera, stamina, and pause/menu UI.
Configuration values live in `assets/default_config.tres` / `CampConfig`.

`python3 tools/verify.py --graphical` exited 0: import, startup, every script parse,
menu checks, and offline physics checks all passed with no engine errors/warnings.
The movement suite passed 11 assertions headlessly and 12 graphically: normalized
diagonals, walking/sprinting speed, stamina/exhaustion/recovery, boundary/wall
collision, cabin entry, and pause. Its initial sprint fixture intersected a tree
collision shape; two failed runs exposed fixture clearance, corrected before this
pass. Captured and inspected the rendered campsite. Snapshot:
[m1_movement](evidence/m1_movement/summary.json).

Objective, AI, and complete-round acceptance remain for the next passes in M1.

## 2026-10-15 — M0: toolchain and runnable opening menu

**Selected scope:** M0 only. Small tasks: inspect repo/toolchain, create the Godot
project and boot screen, bind the specified actions, add docs/folders and local
launch/check tools, verify headlessly and graphically, then commit the boundary.
The M1 task sequence is in [milestones.md](milestones.md).

**Inputs/environment:** `AGENT_BRIEF.md` read in full and treated as authoritative.
`last_night_at_camp_agent_brief.docx` confirmed present and preserved; its contents
were not separately parsed. Initial repository contained only the briefs and a
minimal README. No applicable AGENTS.md was found in the project or its parents.
macOS Darwin arm64, Apple M2. CLI `/opt/homebrew/bin/godot` reports
`4.7.2.stable.official.ed1daf0bf`. Python 3 helper tools use only the standard library.

**Implemented:** Godot Compatibility project, 384×216 viewport with integer scaling
and nearest filtering, opening menu with original geometric forest/cabin scenery,
keyboard/mouse Controls and Quit buttons, field guide with Back/Escape and restored
keyboard focus. Unfinished Play is explicitly disabled. All specified InputMap
actions are configured with physical keys. Created the scene/script/assets/test
structure, setup/architecture docs, repeatable launcher and verification runner.
No external assets or plugins were installed. No gameplay/network stubs were added.

**Verification commands and results:**

| Command | Exit | Observed result |
| --- | --- | --- |
| `godot --version` | 0 | 4.7.2 stable, official build |
| `godot --headless --path . --import` (initial sandbox run) | 0 | Engine filesystem/cache and system-service errors; **not a pass** |
| `godot --headless --path . --quit-after 5` (initial sandbox run) | 0 | Menu loaded, but user-data/system-service errors; **not a pass** |
| Same import and startup commands, approved outside sandbox | 0 each | No engine errors or warnings; menu emitted `menu_ready` |
| `python3 tools/verify.py` (first runner) | 1 | Import/startup/parse succeeded; runner misclassified a parse-only step as a smoke run requiring a test summary |
| `python3 tools/verify.py --graphical` (corrected runner) | 0 | All eight steps passed; no errors or warnings |
| `git diff --check` | 0 | No whitespace errors |

The runner classification bug was corrected by checking exact smoke-step names.
The final runner executed version, import, five-frame startup, individual parse
checks for all three GDScript files, headless menu smoke, and graphical menu smoke.
Every engine step exited 0. Headless smoke: **37 assertions, 0 failures**.
Graphical smoke: **39 assertions, 0 failures**, including both PNG writes.
Tests exercise actual Enter/Escape input and validate bindings, focus, Controls,
Back, and disabled Play. The graphical session reported OpenGL 4.1 Compatibility
on Apple M2. Captured viewport PNGs were opened and visually inspected: title,
scenery, buttons, status and complete field guide text are readable with no clipping.

**Evidence:** final raw logs and JSON are in `artifacts/verification/` (ignored and
regenerated by the runner). The M0 snapshot is preserved in
[evidence/m0](evidence/m0/summary.json), with [menu](evidence/m0/menu.png) and
[controls](evidence/m0/controls.png) screenshots. The report includes each exact
expanded command and its exit/error/warning status.

**Gate:** M0 passed on the available macOS arm64 system: reproducible setup,
working boot/menu, headless import/startup, and zero parse errors. M1 is planned
and not implemented in this increment. No blocker remains for its first walking/
collision pass. No movement, complete round, multiplayer, or exported binary has
been verified; Windows/Linux and other macOS architectures remain unverified.
No exports were attempted.
