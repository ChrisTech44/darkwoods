# LAST NIGHT AT CAMP

Godot 4 cooperative woodland horror game — maintained agent brief.

Version 2.0 — 18 October 2026. Maintained update: 19 October 2026
(ability delivery, host rules and dedicated-server/audio review).

## Authority and current priority

Subsequent user instructions amend this brief. This version replaces the old
accumulated amendments, proposed tuning tables and obsolete initial M0 task.
Historical implementation records remain in [development log](docs/development_log.md).
A specification describes intended behavior; source inspection and execution
records establish what the build actually does. Resolve discrepancies explicitly.

Current design request: replace the six generic survivors with Christian, John,
Max and Alex using the [four-survivor overhaul](docs/four_survivor_overhaul.md).
The four-role replacement and sample framework now have implementations;
see the implementation status and acceptance limits in that document. The four
friends now have dedicated camper sprites/portraits matching their requested
features and clothes, plus money/ability graphics; see the
[art evidence](docs/evidence/camper_art/README.md). Christian must
borrow the full range of creature signatures, including moon-dependent Werewolf
transformation and Paparazzo friendly-fire flashbang/photo consequences. The new
design supersedes earlier roster proposals; preserve its individual drawbacks.
Earlier requests covered friends-playtest fixes, a dedicated-server branch and
guest-lag optimization. Earlier graphics priority: audit defects and plan an overhaul of the map,
Tab notes/help and hint menus so players understand where they are, what is
happening and what to do next. See the
[graphics audit and interface plan](docs/graphics_readability_plan.md).
That document is an implementation backlog, not a claim that the overhaul shipped.
Follow-up priorities are recorded in the [world graphics review](docs/world_graphics_review.md)
and [sound gap/recording review](docs/sound_gap_review.md): world label ownership,
lighting/overlap, phase-title presentation, missing audible feedback and duplicate
trap playback. The later 18 October increment implemented the Tab notebook
(map/plan/guide/log), live map markers, shared field guide, moon dial, phase
titles with a ranger-radio transcript, the duplicate-label/painted-state fixes
and a trimmed, levelled 17-file sound pack (air horn and single bear-trap snap
fixed). Open items are listed at the top of each review and in the log.

## Product requirements

- Original top-down pixel-art horror for 1–4 human survivors against an AI killer.
  Keep solo viable and preserve host authority in co-op.
- Dark woods, cabins, readable localized light, original or authorized assets.
  Maintain provenance; unresolved redistribution records are not resolved by use.
- Keep the game runnable. Deliver coherent verified increments; preserve existing
  survivor abilities, encounters, objectives, sight occlusion and networking.
- Windows, Linux and macOS are targets. Do not infer packaged or cross-machine
  support from macOS editor tests or local loopback peers.

## Current implementation baseline

These are code-backed facts, not a substitute for human acceptance testing.

- Godot project uses a 384×216 game viewport, nearest-neighbor filtering and
  integer scaling; the default window is 1152×648. Current audit engine: 4.7.2.
- Quick Camp and Woods Expedition; fresh random nights by default, explicit
  fixed seeds/retries and Daily Night. Four survivors (Christian, John, Max, Alex),
  a six-slot supply belt,
  separate objectives/tools, health, wounds, downing, teammate rescue and a
  bounded solo recovery mechanism. Consult current code for tuning values.
- Woods have a central camp, ring/spoke roads, thickets, regions, shortcuts,
  fences/vaults, clues, signposts, skyline bearings and player pins. Team trail
  exploration is recorded for every living/downed survivor at the authority and
  replicated as a bounded bitmap; local prediction does not reveal map cells.
- Five implemented escape routes: Van, Radio Rescue, Lakeshore Boat, Ranger
  Gate, Signal Fire. Normal Expedition: van plus one seeded secondary. Quick
  Camp: van only. `--all-escapes` is a diagnostic override, not the normal rules.
- Night phases: Dusk → Nightfall at 20% → Deep Night at 50% → Witching Hour at
  80% of the best prepared escape. Twelve minutes within a phase advances stalled
  teams only as far as Deep Night. Phase timers reset on transition; no dawn
  deadline. Installed/prepared steps count, not simply carried parts.
- The Stalker is the headline killer every night (user decision, 18 October):
  `StalkerTraits` and `CampSong` give the Row, Row, Row Your Boat whistle,
  shadowing, calling cards, grab/hook, hiding memory, rage and bear traps. The
  Groundskeeper is now a woods creature (ride-on mower, rake, spark-plug
  sabotage), one of 31 creatures plus the Stalker each night. All 22 roaming types and all
  regional types now appear every Woods night; no type sits out. Blood Moon keeps
  every type instead of replacing pranksters with werewolves. Its frequent moon
  and faster Stalker remain. Quick Camp retains its single headline killer.
  [Full-roster source/PCK verification](docs/evidence/full_roster/README.md).
- Stalker shadowing: Expedition, Nightfall onward, chosen living survivor in
  eligible woods; nearby clear-sight time before lunging is 90–130s. Ordinary
  SEARCH sightings beyond 40px return to stalking. Deliberate investigations and
  close contact retain detection. Chase is capped at 12s, followed by 3s recovery.
  Only the favourite's beam fades a stalking Stalker within 240px; Space flash is
  separate. Final movement caps at 90px/s; frenzy lasts 12s with 40s rage rest.
- Repeat grabs add 2 presses, capped at +4 above each creature's base (Stalker
  14–18, Vampire 8–12), excluding decay. Stalker decay is 0.06/s and jolts cost
  0.1 progress. Vampire gaze breaks/bite releases start a 6s pull/bite cooldown.
  Witch curses use shuffled bags without adjacent repeats, with replicated cast
  tells/bolt types. Flashlight passive drain is 90/420 charge per second:
  full beam 420s (7 minutes), isolated Alex 560s; other consumers retain their existing charge cost.
- Boat parts install at the marked Lakeshore dock repair pad, with individual
  completion labels. Permanent substation/relay, logging, lakeshore and ranger
  scenery, the boat hull and unlit pyre remain visible independently of tonight’s escapes. Inactive
  gates are raised with no barrier collision; route prompts, parts, power and
  extraction remain limited to tonight’s routes.
- Story events, phase weather, van sabotage and a generator power cut exist.
  Scheduled events can be skipped when their phase is passed before their delay.
  The generator is outside the Maintenance workshop door.
- ENet listen-host co-op, lobby and replicated gameplay are implemented. Opt-in
  proximity voice is implemented through TwoVoIP. Read the
  [audio/voice design](docs/audio_multiplayer_design.md) and
  [multiplayer guide](docs/multiplayer_guide.md) before changing either system.
  Real microphones, listening quality, Internet routing/encryption and packaged
  platform permissions retain their own acceptance limits; implementation alone
  does not satisfy them. Do not capture microphones or enable voice for audits.

## Dedicated server implementation

The current `main` checkout includes an opt-in command-line authority for 1–4 human clients,
with no server survivor. `tools/run_server.py` forces headless display, disabled
render loop and Dummy audio; server paths skip voice codec/capture/playback.
Source launch first imports assets/registers script classes and refuses to start
after import errors, including when Godot exits zero. Exported packs skip import.
Minimum-player/all-ready start, automatic results-to-lobby reset and empty-round
cleanup are implemented. The game protocol is `lnac-net-21`, compatible with
updated main clients. The portable PCK needs Godot 4.7.2 on the target machine.
The October 19 [server review](docs/server_review.md) fixes mixed-role assignment,
batched-disconnect packet sends and stale package metadata. Actual four-client
source/PCK and disabled-rule runs cover these changes; target OS and Internet
acceptance remain separate. See [server guide](docs/dedicated_server.md); execution/OS limits remain separate
acceptance gates. This supersedes the older branch-only status: dedicated source is present in main and executed by the current rule checks. It includes measured redraw caching,
bounded prediction/reconciliation and buffered remote motion; see evidence below.

## Movement transport

Rules are `lnac-net-21`: authority-only 30Hz player packets include applied-input
acknowledgements, bounded owner movement state and server-detected discontinuity
counters. The owner predicts shared collision/movement immediately, with no AI
hearing, blood or gameplay outcomes; authoritative fields are restored after each
presentation step. Recent input history and prediction freshness are bounded to 250ms, corrections ease at up to
180px/s, and genuine server relocations reset presentation. Other survivors and
enemies use an 80ms interpolation buffer, at most 50ms extrapolation and bounded
recovery steps. Full world snapshots remain independent at 20Hz with unordered
fragments; stale world state cannot overwrite newer player poses. Pickup/site
art remains cached until replicated state changes. Clients and listen/dedicated
servers must update together. See [smoothness evidence](docs/evidence/smoothness/README.md)
and [network investigation](docs/network_lag_investigation.md) for executed
measurements and limits; no complete cure for multi-second link loss is claimed.

Current copied-ability presentation, audio, host rule and interaction audit:
[ability feedback review](docs/ability_feedback_review.md). Camper powers may be
disabled offline, in the listen lobby, or with `--no-camper-abilities` on a server;
the host locks the passive/active rule per round. Calling cards begin after an
8s clock, then recur every 24s when physically within 230px.

## Interface and graphics direction

The [audit plan](docs/graphics_readability_plan.md) defines the next work slices.
Keep inventory, objective state, map knowledge and contextual help consistent.
Show an immediate next action, its location, and any blocking prerequisite.
Differentiate unknown, region known, cache found, carried, dropped, installed and
sabotaged states. Preserve clue discovery: do not reveal hidden objects or enemies.
Use shared gameplay state for text and markers; never trust a client to invent
objective progress. Presentation must not alter AI or world authority.

Map, escape plan and field guide must have distinct allocated space and readable
navigation. Provide complete keyboard navigation and mouse support. Do not rely
on color alone. Keep event information available after a transient banner expires.
Online menus must state that the world continues; preserve the existing offline
pause policy. Audit normal lighting as well as deliberately bright inspection
views, and label staged/forced scenes honestly.

## Verification and evidence

After every change run:

```sh
godot --headless --path . --import
godot --headless --path . --quit-after 5
git diff --check
```

Run applicable integration suites in `tests/integration/`; `python3 tools/verify.py`
is the broad regression runner, with `--graphical` for its graphical checks.
Use narrower checks for documentation/capture-only increments; do not claim the
full suite ran unless it did. Graphics changes require actual graphical captures
and visual inspection; headless success does not establish appearance.

For the baseline interface audit:

```sh
godot --path . --audio-driver Dummy --script res://tools/capture_readability_audit.gd
```

Record commands, exits, warnings, screenshots and limits in the development log.
Keep raw temporary artifacts ignored; preserve selected evidence in `docs/evidence`.
Check changed Markdown links and rules against implementation. Label untested
platforms, human readability, cross-machine networking and microphone acceptance.
Never equate an exit code of zero with a clean run if engine errors were printed.

## Working and publishing rules

Follow [AGENTS.md](AGENTS.md): verify each coherent increment, update the log and
relevant player documentation, fetch, commit intended changes, push the current
branch to origin and confirm the remote commit. Preserve remote and unrelated
work; never force-push or rewrite published history. Report exact publication
blockers. Keep specifications and plans in Markdown only.
