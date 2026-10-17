# Current network increment

ENet listen-host gameplay is implemented in both modes and exercised with two
and four independent local peers plus scripted graphical windows. See the
[multiplayer guide](multiplayer_guide.md). Human baseline, real cross-machine
Internet, synchronized-audio listening, latency/jitter and voice acceptance are
still pending; loopback evidence does not pass those gates. The older staged
plan below is retained as historical milestone/acceptance context.

# Next: the fun overhaul track (F1–F8)

Planning only; nothing below is implemented. The user wants nights that are more
fun, dynamic and heart-pounding, and is open to map redesign, new regions and
cross-map requirements. Full design: [gameplay overhaul plan](fun_overhaul.md).
Before F1, record one **human baseline night** (solo and two-peer) with the
plan's pacing metrics so every slice can show improvement.

| Slice | Smallest shippable content | Gate (solo + two-peer co-op, graphical evidence, logged) |
| --- | --- | --- |
| **F1 Navigation** — *implemented, human pacing pending* | Skyline markers, junction signposts, wall-map region outlines, three shared map pins per player (M), second boltcutters and noisy crowbar. Clue chains moved to F4. | Passed: arrows follow shortest trails on four seeds, markers bounded/edge-clamped, pins host-accepted and replicated (2/4 peers), tools reachable ([evidence](evidence/navigation/README.md)). Pending: recorded human route timing. |
| **F2 Night phases** — *implemented, human pacing pending* | 60-minute host clock (Dusk 0–10, Nightfall 10–25, Deep Night 25–40, Witching Hour 40–60, dawn rescue), radio part reveals, dread, director with relief windows, phase supply drops, Storm Front, Blackout + generator, dread-scaled music and stingers, stalker escalation. | Passed: seeded schedule, sealed parts until their phase, no in-range/in-camp director use, relief windows, storm hearing ×0.6, lamps/generator, dawn rescue vs left-behind, network phase replication ([evidence](evidence/night_phases/README.md)). Pending: human 40–60 min pacing and supply balance. |
| **F3 Chase toolkit** — *implemented, human pacing pending* | F3a: Wounded + blood trail, medkit patch, kitless revive, revived-wounded, crawl + help ping, solo last chance/self-recovery, flash-stun. F3b: hiding spots (camp furniture, woods brush) with breath meter and witnesses, slam/break doors with light occlusion, one-use knock-overs. Vaults move to F4. | Passed: injury, revive and flash rules ([F3a](evidence/chase_toolkit/README.md)); spot reachability, invisibility/immunity while hidden, breath gasp, witness drag-out, live AI breaking a door to reach a noise, knock-over block/stun/expiry, hide + door replication with client collision ([F3b](evidence/chase_props/README.md)). Pending: human close-call:down ratio. |
| **F4 Ring-and-spoke map** — *F4a implemented; F4b next* | F4a: lit ring road through village/bog/graveyard, four spokes to the edges, lamps on camp power, roads on the field map, maze kept as thickets. F4b: rotating objective regions with camp → field → building clue chains, one unlockable shortcut per spoke, fences to vault. | F4a passed: same roads every seed, all 2,410 clearings connected, road surfaces clear three lanes wide, ring through all three objective regions, nav-measured walks 18–30s to required regions (target ≤ 60s), blackout darkens road lamps ([evidence](evidence/road_network/README.md)). Pending: F4b; human route feel. |
| **F5 Escapes & new regions** | Radio Rescue (Power Substation + Radio Relay Station) with landing-zone hold-out; then Boat (Logging Camp + Lakeshore Boathouse) and Ranger Gate. Van gets its hold-out finale. | Each chain spans ≥ 3 spokes, solo-completable by every role; finale convergence bounded; results report escape type. |
| **F6 Roles 2.0 & co-op** | Role active abilities, item passing, heavy items with two-carrier speed, two-person actions with solo fallbacks, ghost wisps, end-of-night awards. | Abilities host-validated and cooldown-bound; wisps reveal only explored trails; four Scouts and a solo Quiet Kid still win. |
| **F7 Killers & modifiers** | Stalker tiers 1–4 and once-per-night sabotage; first new headline killer (The Groundskeeper); six night modifiers. | Sabotage displaces, never destroys, and marks the region; modifiers shown on loading card and reproducible by seed. |
| **F8 Meta-progression** | Score and grade, daily seed, per-seed best table, camp journal, merit badges and unlocks; then the five-night campaign. | Local save is versioned and corruption-tolerant; unlocks are cosmetic/side-grades validated by the host. |

F1–F3 precede M3-V proximity voice; voice may run in parallel after F3. Each
slice keeps the game runnable and pushes verified increments per `AGENTS.md`.

# Incremental implementation plan

Latest user amendment: the offline content update is implemented ahead of M2;
see [content rules and verification limits](content_update.md).

M0 passed and was committed as `ef180d0`. M1's offline implementation and the
requested forest expansions are complete. All five steps below are covered by automated
engine checks. Full input-driven win/loss/restart runs pass headlessly and in a
real graphical session. A human playtest at normal speed remains unrecorded;
do not describe that manual gate as executed. Multiplayer remains M2.

User-requested follow-up: boarding is now explicit and protects seated survivors,
and an authorized visual/map pass expands the camp to 1536×960 with ten furnished
buildings, original character/environment pixel art, shadow-casting lights and a
field map. The user's subsequent request explicitly authorizes woods,
replayability and UI polish ahead of M2: a seeded finite trail maze, five-part
repair/cache objectives, tools/supplies, weather and six original cryptid types
(originally four creatures per expedition; now 24), interactive village/bog/graveyard sites and richer sensing,
search, patrol and projectile behavior. Quick Camp retains M1's three-part objective with randomized camp positions.
That earlier content increment did not implement networking; the current ENet increment is described above.

## M1: offline vertical slice, one verified pass per step

1. **Walking in camp.** Wire Play to a small ForestLevel, original placeholder
   Player, eight-direction movement, facing, sprint/stamina, camera, and solid
   forest/cabin boundaries. Add a configuration Resource for speeds/stamina.
   Gate: manual traversal, diagonal normalization, blocked-wall and stamina checks;
   return to menu works. Keep the scene readable before introducing darkness.
2. **Supplies and van.** Three distinct components, proximity-validated pickup,
   inventory HUD, single-award interaction, component delivery, hold to start,
   configurable countdown, extraction, results, and restart. Gate: complete a
   local escape; distant/duplicate pickup and repeated delivery rejected.
3. **Stalker senses.** One killer with PATROL/INVESTIGATE/CHASE/SEARCH, raycast
   sight, recent noise, navigation, target-loss decay, and stuck recovery.
   Gate: walls occlude sight; sounds trigger investigation; lost targets are
   searched at last sensed positions instead of tracked through walls.
4. **Consequences and round lifecycle.** Down/second-hit elimination, attack
   cooldown, timed revive interaction, defeat when no player can continue,
   per-player outcome, and clean replay. Gate: one complete local win and loss;
   revive verified with a controlled fixture until multiple humans exist in M2.
5. **Visibility and acceptance.** Flashlight, readable night overlay, telegraphs,
   controls/pause/inventory, full local round regression and graphical evidence.
   Gate: a human completes or loses an entire round and restarts successfully.

For each step, record commands, results, and remaining gaps in development_log.md.
Run import/startup and applicable tests before advancing; use configuration values
for mechanics and add tests when they validate real rules. Commit at M1 acceptance.

## Next steps: real cross-machine acceptance and voice

The 16 October planning amendment adds an offline survivor selection milestone
before networking, plus a deliberately staged content backlog. The detailed
[survivor/co-op plan](survivor_multiplayer_plan.md) defines six archetypes,
proposed values, screen flows, lobby rules and verification. Selection/bonuses
are **implemented offline**, with automated and graphical checks; the human
balance and full all-role input-round gates remain pending. Existing M1 human acceptance remains unrecorded.

1. **M1-S selection shell:** six cards, readable details/preview, saved choice,
   explicit Random Survivor, Back/Start, settings/music and retry flows.
2. **M1-S personal bonuses:** data-driven role IDs, private effective stats,
   stamina/light/noise/ignition/revive/supply modifiers and accurate HUD.
3. **M1-S verification/human baseline:** all six roles in both modes, reset and
   contamination checks, real graphical input and recorded normal-speed play.
   Keep solo victory possible; teammate fixtures do not establish networking.
4. **M2 authority in Quick Camp:** two real ENet peers, selection/ready lock,
   inputs/spawns, contested items, killer/revive, van/boarding and shared results.
5. **M2 existing expedition parity:** current woods, roles, all 25 enemies,
   projectiles/sites/caches/weather, per-player sight, restart and disconnect.
   Verify this before advertising expedition co-op; do not add the full monster
   catalog while establishing synchronization.
6. **M2-A → M3 → M3-V → M4:** synchronized audio, four-peer gameplay reliability,
   then optional online voice and verified packages, using the gates below.

## Network, audio and distribution gates

- M2: ENet listen-server lobby with host-validated archetypes/ready state, two
  local clients, synchronized mechanics, deterministic two-client assertions
  and manual two-window smoke test. Reject forged stats/unknown IDs; lobby-only
  late joins and no reconnect supply refresh. Test duplicate and mixed roles.
- M2-A (after M2): extend the existing local audio-file/AudioManager/mixer
  foundation and complete cue/provenance gaps. Replicate positional world cues
  authoritative sound events once per receiver; keep AI hearing independent of
  device volume. Gate: two-client cue/cleanup checks and a real listening session.
- M3: four players, simultaneous interactions, disconnect/host loss, lobby-only
  late join, shared restart, and practical latency checks.
- M3-V (after M2-A and M3 reliability): online proximity voice with opt-in
  microphone enablement, push-to-talk, distance falloff, wall muffling, per-peer
  mute/volume, device feedback and separate spectator speech. Gate: a complete
  two-machine round across networks using a documented connection method, then
  four-peer/load/jitter/reset checks; no-mic/denied-permission players can join.
- M4: desktop export templates/presets, verified available builds, platform status
  and launch notes. Package actual audio files and any codec dependencies; verify
  microphone permissions and playback/capture on each claimed target. No exports
  before the applicable milestone passes.
- M5: staged replayability/polish from the approved planning backlog. Alternate
  extraction, objective-region rotation, night phases and progression are now
  scheduled as the F-track above, with per-slice verification. No catalog size
  is a release/voice gate.

The user has approved including future online voice and audio files in the
design. This does not mark them implemented or collapse the incremental gates.
See [audio and multiplayer design](audio_multiplayer_design.md) for proposed
defaults, event/voice boundaries, content priorities and acceptance criteria.

## Expanded monsters and biomes: staged content track

The [monster catalog](monster_catalog.md) adds **48 concepts** to the seven
existing designs. The [biome document](biome_design.md) describes **18 regions**:
expanded graveyard/village/bog and 15 new landmark pockets, with layout,
interactions, encounters, randomness and acceptance checks. These are designs,
not shipped enemies or locations. The current 24-cryptid expedition is unchanged.

Prototype one slice after M1-S/human baseline, then integrate it after M2/M2-A
stabilize. First candidates are **Flooded Mill + Boiler Saint**, **Orchard +
Bramble Seamstress**, **Observatory + Shutter Wraith**, and **Rail Yard + Last-Car
Conductor**. Keep each independently runnable and verified. Use navigation and
sight reservations, safe return loops, optional rewards, bounded encounters and
original/licensed art/audio. No required role/microphone, permanent route seal,
remote trail reveal or automatic 48-enemy population increase.

For each slice: schematic/reservation → scenery and collision/sight/nav → one
interaction → one monster/tell/counterplay → seeded variants → online parity.
Require actual graphical inspection, solo human counterplay, all-role access,
one-time reward/reset checks and, once networked, two/four-peer event consistency.
Retain three current objective regions and the five-part recipe initially. Add
only a small verified subset of the biome pool to a given random night.

## 16 October priority amendment

Before networking or voice: correct visual/map bugs, add seeded camp building
variation with aligned loot/door paths, and integrate the supplied MP3 cues.
Verify local audio independently; M2-A still requires future two-client evidence.

Offline layout/audio implementation now includes seeded camp lots and all 14
user-supplied MP3 cues, saved mix controls and local cleanup/decode tests. Asset
license documentation and human listening remain unverified; this does not pass
the synchronized M2-A gate or any voice/platform/export gate.

Menu/defaults amendment: pre-game music/mixer, random camps in both modes by
default, wider seeded offsets/compatible building swaps, and solid woods shadow
borders now precede networking/voice. Explicit seed/retry still reproduces runs.

The forest-surround amendment adds a finite 9600×9408 central-camp world, 2410
forest clearings, four camp exits, spacious region aprons, 24 surrounding
creatures, local field-map navigation and opaque woods sight. Native navigation
uses bounded bakes and explicit readiness; random-seed/global-connection evidence
is required before publishing. This remains offline polish ahead of M2.
