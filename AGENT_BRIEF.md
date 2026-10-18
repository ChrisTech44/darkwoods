# LAST NIGHT AT CAMP

Godot 4 cooperative woodland horror game — maintained agent brief.

Version 2.0 — 18 October 2026.

## Authority and current priority

Subsequent user instructions amend this brief. This version replaces the old
accumulated amendments, proposed tuning tables and obsolete initial M0 task.
Historical implementation records remain in [development log](docs/development_log.md).
A specification describes intended behavior; source inspection and execution
records establish what the build actually does. Resolve discrepancies explicitly.

Current user request: audit graphics defects and plan an overhaul of the map,
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
  fixed seeds/retries and Daily Night. Six survivor roles, a six-slot supply belt,
  separate objectives/tools, health, wounds, downing, teammate rescue and a
  bounded solo recovery mechanism. Consult current code for tuning values.
- Woods have a central camp, ring/spoke roads, thickets, regions, shortcuts,
  fences/vaults, clues, signposts, skyline bearings and player pins.
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
  sabotage), one of 30 creatures per night; nine kinds were added on 18 October
  and one of the 22 roaming kinds rests each night (rotating by seed).
- Shared shadowing is conditional: Expedition, Nightfall onward, PATROL,
  chosen living survivor in eligible woods. Only that survivor's beam triggers
  fading within 240px and clear sight. CHASE/INVESTIGATE/SEARCH bypass this beam
  check. Space flash is a separate short-range stun. Do not describe continuous
  flashlight repulsion or Stalker-exclusive shadowing as current behavior.
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
