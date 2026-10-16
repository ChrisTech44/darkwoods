# Development log

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
