# Development log

## 2026-10-16 — Overhaul F4a: ring road, spokes and lamps

First half of the map redesign, aimed at the original "puzzling, tedious to
search" complaint.

- `WoodsLayout._make_roads()` adds a deterministic ring road around camp (cells
  x16–33 by y17–31). It passes through the village, bog and graveyard. Four
  straight spokes run from the camp exits to the map edges. It uses no RNG, so
  every other seeded element is unchanged. Road links are added to the graph and
  carved 160 px wide (64 px past each end, so road ends meet existing trail
  squares). Road tiles render as dirt; region clearings keep their own ground.
- Lamp posts every two cells on the ring and inner spokes (not inside regions;
  about 33–34 per night) use camp power: they join `camp_lamps`, so blackouts
  darken them. The outer spokes are unlit logging roads. The field map prints
  the roads from the start, and the location line reads LIT ROAD, ROAD (POWER
  OUT) or LOGGING ROAD.
- Pack radio lines are shortened to `PART / RADIO AT mm:ss` so they no longer run
  under the field map.

**Regression found and fixed:** the first carve extended roads 80 px past their
ends. That widened the camp's west exit into a thin wall stub, and the
expedition bot snagged on the stub's corner. Rather than special-case the bot,
roads now extend only the trail half-width along their length. The camp edge is
back to its original solid wall and the unmodified bot completes the
expedition.

Measured on night 42 (native navigation from camp centre at 70 px/s):
graveyard 17.5 s, bog 28.0 s, village 30.1 s, mill 40.5 s, orchard 43.7 s,
chapel 44.9 s, rail 50.1 s, observatory 54.8 s, quarry 69.4 s. Rules
`lnac-net-8` because generated woods differ from older builds.

**Verification:** `python3 tools/verify.py` 89/89 steps, no errors or warnings
(new `road_network`: 19 headless / 22 graphical assertions).
`verify_network.py --mode all`: 2 peers 269 and 4 peers 455 assertions, all
passing. Evidence: [road network](evidence/road_network/README.md). Not
verified: human route feel, light performance on slower hardware, other
platforms.

## 2026-10-16 — Playtest fixes: knock-overs close the trail; doors close on the run

User playtest feedback, three points:

1. **"The woodpiles don't exactly block the path."** Confirmed. A 44 px log fell
   along the player's facing, but woods trails are 128 px wide and camp piles
   sat in open ground. Knock-overs now sit only on straight trail stretches.
   Each measures the open trail across its axis (walkable tiles, up to 180 px)
   and precomputes a fall line 8 px into both walls. Woodpiles are the first 4
   such stretches 750–1,300 px from camp; deadfalls are up to 60 deeper in. The
   survivor who topples it is placed on the far side from the nearest creature
   (else their own side). The log never solidifies over another survivor. The
   fallen-log art is now chunkier.
2. **"Are you supposed to be able to move when downed?"** Yes: the planned
   20 px/s crawl. Left unchanged pending the user's call.
3. **"The doors aren't that easy to close when you run in."** Cause: pressing E
   while still in the 24 px thick doorway hit the "Something is in the doorway"
   guard, because the acting player counted as a blocker. Now the actor is
   excluded and stepped through toward their heading. Reach went from 18 to
   22 px. Door prompts win over nearby hiding spots and piles (the nearer target
   wins unless you're in the gap). Hiding spots are no longer placed within
   30 px of a door.

Tests: `chase_props` now proves full-width closure (15 parallel lanes blocked
across both a woodpile and a deadfall), far-side placement, slamming from the
doorway, and refusal only when someone else is in it. The network hide stage
picks an item-free spot. The knock-over capture is an inspection shot (raised
ambient, no sight mask).

**Verification:** `python3 tools/verify.py` 87/87 steps, no errors or warnings
(`chase_props`: 43 headless / 46 graphical). `verify_network.py --mode all`:
2 peers 269 and 4 peers 455 assertions, all passing.

## 2026-10-16 — Overhaul F3b: hiding spots, doors and knock-overs

Second half of the chase toolkit, in a host-owned `ChaseProps` node
(`scripts/world/chase_props.gd`).

- **Hiding:** one or two spots per building, placed beside bunks, cots,
  lockers, crates, canoes, tables or desks on clear interior ground, plus brush
  spots on woods corridors (separate RNG, spaced 520 px). Night 42 has 18 camp
  spots, 195 brush spots, 9 woodpiles and 60 deadfalls. Hidden survivors
  snap in, can't move, are skipped by AI senses, dashes, hazards and bolts, and
  their light switches off (restored on leaving). Breath drains 0.25/s within
  120 px of a creature and recovers 0.2/s; at zero they gasp (220 px noise) and
  pop out. Creatures chasing or seeing the survivor at entry become witnesses
  for 15 s: they investigate the spot and drag the survivor out on arrival.
- **Doors:** every building gets a door body in its wall gap (`door_rect` added
  to `CampBuilding`). E slams (120 px noise) or opens it; it won't close on a
  survivor or creature. Closed doors block movement, sight raycasts and
  flashlight light (a light occluder was added after a graphical capture showed
  the beam leaking through). Creatures pressing within 18 px break it in 2.5 s
  (300 px crash); it stays smashed for 20 s.
- **Knock-overs:** woodpiles beside camp doors and up to 60 deadfalls (spaced
  900 px). E topples one along your facing, blocking a 44×12 lane for 6 s and
  stunning creatures in it for 2 s (stun immunity applies). It is never solid if
  that would trap a survivor. One use.
- Snapshot carries door/knock state and per-player hide/breath. Clients apply
  door collision so their sight raycasts match. Rules `lnac-net-7`.

Bugs caught by tests before commit:
- Door reach measured from the centre missed thick cabin walls; it's now
  measured from the door edge.
- A live-AI test showed the crash noise overwrote the breaker's own target, so
  it investigated its own noise and wandered off. The breaker now keeps its goal
  and only other creatures turn toward the crash.

**Verification:** `python3 tools/verify.py` 87/87 steps, no errors or warnings
(new `chase_props`: 33 headless / 36 graphical assertions).
`verify_network.py --mode all`: 2 peers 269 assertions, 4 peers 455, all
passing. Evidence: [hiding/doors](evidence/chase_props/README.md). Not
verified: human feel of breath timing and door break time, graphical network
windows, other platforms.

## 2026-10-16 — Overhaul F3a: wounds, revives, crawl, self-recovery, flash-stun

First half of the chase toolkit, aimed at more close calls and fewer instant downs.

- **Wounded before downed:** the first hit sets `wounded` with 1.2 s of
  invulnerability; a second hit downs. Wounded survivors sprint ×0.9 and drop
  up to 14 blood marks (every 18 px). Every 2.5 s, patrolling creatures within
  110 px of the newest drop investigate it. A medkit + V clears the wound.
  Revived survivors return wounded.
- **Revives:** a medkit is no longer required. Bare-handed takes 2× the role's
  revive time (6 s base, 4.5 s First-Aid Kid); with a kit it takes the role time
  and uses the kit.
- **Downed:** crawl at 20 px/s; E calls for help when teammates exist (8 s
  HELP edge marker for everyone, 160 px noise, 10 s cooldown).
- **Solo:** a lone survivor gets 20 s after going down to hold E for 8 s and get
  up, once per night (500 px noise). Otherwise all-down defeat applies as before.
- **Flash-stun** (Space, `flash_burst`): costs 15 charge in expedition, 8 s
  cooldown. Creatures within 90 px in a 0.75-dot cone with clear line of sight
  freeze for 1.5 s (no movement, attacks, dashes or casts), then can't be
  stunned again for 6 s.
- Snapshots carry wound/flash/help/self-recovery state and enemy stun; downed
  peers may send `interact` (help), and `flash` is a new intent. Rules `lnac-net-6`.

Tests: `offline_slice` updated to wound-then-down and solo last chance; the
network revive check now asserts kitless is slower than kit time. A test
side-effect (re-disabling a stunned stalker froze its stun) was fixed in the
fixture, not the game.

**Verification:** `python3 tools/verify.py` 84/84 steps, no errors or warnings
(new `chase_toolkit`: 29 headless / 30 graphical assertions).
`verify_network.py --mode all`: 2 peers 261 assertions, 4 peers 439, all
passing. Evidence: [chase toolkit](evidence/chase_toolkit/README.md). Not
verified: human close-call:down ratio, balance of the 20 s solo window, graphical
network windows, other platforms.

## 2026-10-16 — Overhaul F2: the 60-minute night

User amendment: expedition rounds should span **40–60 minutes**. Implemented as
a host-owned `NightClock` (`scripts/core/night_clock.gd`) in Woods Expedition;
Quick Camp stays short with the clock inactive.

- **Phases by clock:** Dusk 0–10, Nightfall 10–25, Deep Night 25–40, Witching
  Hour 40–60, dawn at 60:00. The plan's "time or progress, whichever first" rule
  was replaced; progress feeds dread instead, keeping the 40-minute floor.
- **Ranger-radio reveals:** battery/key at Dusk, fuel at Nightfall, extra parts at
  Deep Night and Witching Hour (`RoundPlan.reveal_phase`). Sealed caches are hidden
  and unavailable; Tab shows each part's radio time.
- **Dread and director:** dread = phase base + progress through the phase +
  decaying noise heat + 3 per installed part. Every 75→25s (by dread) the director
  steers 1–2 patrolling roamers 700–1,800 px away, never within 400 px of any
  survivor, never guardians, to a point 150–300 px from a woods survivor. It never
  targets camp and skips anyone chased in the last 45 s.
- **Events and supplies:** seeded storm (Nightfall), blackout (Deep Night) and
  a random third in the Witching Hour. Storms scale all AI hearing ×0.6 for 90 s
  with lightning flashes; blackouts disable camp lamps (the campfire keeps
  burning) until E at the Maintenance generator (450 px noise). Each phase drops
  2 batteries, a flare and a ration at Maintenance.
- **Escalation and audio:** stalker hearing ×1.1 at Deep Night and Witching Hour,
  chase speed ×1.08 at Witching Hour. Music gain and pitch follow dread; a
  distant howl on the Music bus marks each phase. It is a score stinger, not a
  positional creature call, so the proximity-call rule still holds.
- **Dawn:** survivors in camp or aboard are rescued (downed in camp too, if anyone
  is); anyone in the woods is left behind.
- Snapshots carry the night state; clients don't simulate it. Rules `lnac-net-5`.

Test updates: the replay test now checks fuel is sealed until Nightfall, then
advances; the full-expedition bot uses `reveal_all()` with the director off, so
it stays a route regression. The audio test expects dread-scaled music. The
network test adds a host-advanced Nightfall stage. Diagnostics showed a client
HUD lagging the snapshot by a frame, so the stage now waits three frames.

**Verification:** `python3 tools/verify.py` 81/81 steps, no errors or warnings
(new `night_phases`: 40 headless / 41 graphical assertions).
`verify_network.py --mode all`: 2 peers 251 assertions, 4 peers 421, all passing.
Evidence: [night phases](evidence/night_phases/README.md). Not verified: a human
40–60 minute night, light/supply balance over a full night, graphical network
windows, other platforms.

## 2026-10-16 — Overhaul F1: navigation aids, team pins and spare lock tools

Continued the user's gameplay overhaul with slice F1 to cut "puzzling, tedious"
searching in the large maze.

- **Signposts:** `WoodsLayout` places about 120 signs per seed at trail junctions
  (spaced ≥ 640 px, outside regions). It uses graph data only, so older seeded
  content is unchanged. Boards point along the shortest trail to camp and the
  two nearest regions; the HUD prints full directions when the sign is in sight.
- **Skyline markers** (`scripts/ui/skyline.gd`): camp plus up to four regions within
  2,400 px, clamped to a HUD-safe edge band. They give direction only and are
  hidden in camp.
- **Field map:** shows every region outline/name in view from the start (Lodge
  wall map); visited regions brighten. Trails remain exploration-only.
- **Team pins:** new `map_pin` action (M). Host-accepted `pin` intent, newest
  three per owner, replicated in snapshots, shown on the map and as edge markers.
  Rules version bumped to `lnac-net-4`.
- **Spare tools:** a second boltcutters pair in a woods toolbox 1,000–1,600 px
  from camp, with a compass bearing in the pack, and a crowbar in the free bunk
  cabin. The crowbar opens caches with a 500 px noise. A survivor can carry only
  one of each, so the spare is left for a teammate. These use a separate RNG
  stream, so existing loot and encounter seeds don't shift.
- Clue chains moved to F4: the pack already names each exact cache today.

Graphical review caught and fixed three layout issues before commit: edge labels
hidden by the belt, stacked nearby pin labels, and a pack line running under the
field map. Signpost spacing initially compared cell centres to offset
positions; the new spacing assertion caught it.

**Verification:** `python3 tools/verify.py` 78/78 steps passed with no errors or
warnings (new `navigation_aids` suite: 45 headless assertions; graphical run 48
with three captures). `verify_network.py --mode all` passed 2 peers (6
processes / 248 assertions) and 4 peers (8 processes / 414 assertions),
including the new guest-pin replication stage. Evidence:
[navigation](evidence/navigation/README.md). Not verified: human pacing (time to
find regions), graphical network windows for this increment, other platforms.

## 2026-10-16 — Gameplay overhaul planning (fun, dynamic, heart-pounding)

User feedback: searching feels puzzling and tedious, and nights are not very
replayable. The user wants the game more fun, dynamic and tense with friends, and
is open to map redesign, new regions and cross-map requirements. Added
[docs/fun_overhaul.md](fun_overhaul.md) as the authoritative design direction:
a code-grounded diagnosis (70 px/s walking in a 9,600×9,408 maze, three required
caches in three directions, one shared boltcutters, low-value optional sites,
flat threat, one-hit downs) plus pillars, night phases with dread and a bounded
director, night events, a chase toolkit (Wounded state, hiding, doors, vaults,
knock-overs, kitless revive), ring-and-spoke map with skyline landmarks and
shortcuts, clue chains and map pins, rotating objective regions, five escape
types with cross-map chains and hold-out finales, co-op actions, replayability
(headline killers, modifiers, scores, journal, unlocks, campaign), pacing
metrics and the F1–F8 delivery track.

Amended the brief (new amendment, pillars, F-track, ordering: F1–F3 before
M3-V voice), milestones (F-track table and gates), survivor plan (Roles 2.0
active abilities, unlockable roles, wisps, awards), monster catalog (rule
amendments, stalker tiers/sabotage, headline killers H01–H04), biome design
(ring-and-spoke structure, objective rotation, regions B19–B26 and F4–F5
acceptance) and audio design (dynamic music/stingers/hiding audio, walkie-talkie
and opt-in voice-noise modifier ideas). Updated "voice is next" statements in the
README, multiplayer guide and architecture doc. Planning only; no gameplay
code, assets or tests changed and none of these systems are implemented.

Verification: all relative Markdown links and heading anchors across README,
brief and docs resolve (0 broken); `git diff --check` passed; required Godot
4.7.2 headless import and five-frame startup both exited 0 with no errors or
warnings. Documentation-only change; no new screenshots.

## 2026-10-16 — GitHub item reference with locations and effects

Expanded the README with a linked **Items** section covering all seven van
components, reusable boltcutters, built-in flashlight and seven supply types.
Tables distinguish both modes' spawn locations, seeded objective-cache assignment,
starting-role bonuses, scattered woods loot and optional landmark rewards.
Documented one-time well/crypt stashes, noisy cauldron interaction, exact supply
values/controls, six-type belt stacking, automatic medkit use and drop/recovery.
Explicitly distinguished van battery from flashlight batteries and noted that
Quick Camp has no ground medkits or extra supply stashes.

Checked rules against RoundPlan, SurvivorRoster, ForestLevel, ForestSite, flare/
lure behavior and pickup locations. Existing screenshots retained; README image
paths/local links/heading anchors all resolve. Required Godot headless import
and five-frame startup both exited 0 with no errors/warnings; `git diff --check`
passed. Documentation-only change; no gameplay code or new tests.

## 2026-10-16 — Active enemies through downs and scoped interaction feedback

Confirmed that enemy senses still selected DOWNED actors after the indefinite-
down amendment. They could stand on an invulnerable body instead of hunting a
standing teammate. Senses now accept ALIVE targets only; attackers clear a target
immediately after downing it and enter SEARCH. Witch casts reject downed targets.
Idle navigation recovery now counts non-arrival with zero movement, including
finished/unreachable paths that previously bypassed the stuck timer. Authored
spell wind-ups, flare reactions and Shutter Wraith beam counterplay remain.

The stalker starts on central roads in both modes, sweeps the campsite early,
then tours a seed-varied perimeter. Every seed keeps the early sweep. Movement
speed, senses and collision are unchanged; no omniscient tracking or teleports.

Ordinary interaction/supply feedback now uses each actor's replicated notice
and only their own HUD. Empty E, locked-cache/belt errors, pickups and drops no
longer replace everyone's banner. Shared injury/revive/engine events remain
shared. Fixed a second interaction issue: a nearby downed teammate no longer
swallows E when the rescuer lacks a kit, allowing dropped gear/medkits to be
recovered. Rules version is `lnac-net-3`; both copies must update.

Real graphical ENet tests: two peers/both modes **244 assertions**; four peers/
both modes **410 assertions**. **14 process runs / 654 assertions**, all pass,
zero errors/warnings. Added living-target preference over a closer body, actual
native stalker/roamer movement through four alternating host/guest down/revive
cycles, replicated stride/enabled state on every client, kit recovery beside a
body, and owner-only empty-E feedback. All 49 expedition enemies are enabled
during these cycles with fixture wards and controlled positions. This is real
host AI/replication evidence, not human balance or separate-machine Internet.

The reported alternating-down defeat was not reproduced after a successful
revive; all tested cycles continued while a survivor was standing. All-down
still intentionally ends defeat. Initial unit movement/item fixtures were caught
by the earlier stalker patrol; isolated those fixtures from AI and retained live
AI in dedicated movement/authority tests and full input-only rounds. The solo
Quick Camp bot now chooses a reproducible Jock and natural battery/fuel/key order,
then waits on the central sweep for its loss check. The forest bot uses
Overprepared supplies and normal belt keys for carried ward/moss counterplay;
no outcome edits, teleporting or disabled enemies in those full rounds.

Final `python3 tools/verify.py`: **75 steps passed**, no errors/warnings,
including required import/startup, input-only Quick Camp win/loss, and Woods
escape with all 49 enemies active (**200 assertions**, 12,502px, one flare left).
Content regression: **350 assertions**, zero failures. Documentation links/anchors
and `git diff --check` passed before publishing.

[Network reports and raw logs](evidence/active_ai/README.md) preserve execution.
Player guide/README/spec/architecture describe targeting, scoped notices and
current defeat rules. Voice/microphone APIs remain unchanged.

## 2026-10-16 — Center names, indefinite downs and shared survivor lighting

Applied the user's rescue/lighting amendment. Names now center by measured font
width. Removed second-hit elimination and timed bleed-out; repeated downs are
idempotent. A down drops every objective/tool/supply unit once, clears the belt,
and searches wall-clear reachable ground at least 32px from the body. Pickups
render above actors as a cramped-space fallback. Disconnect drops all gear too.
A medkit is mandatory for revival, consumed only after the full hold (3s, medic
2.25s); no bonus refresh. Any successful passenger escape rescues connected
downed teammates. Living survivors still board; all-down ends defeat without
permanent death. HUD/selection text and player guides explain these rules.

The replicated flashlight toggle/facing already existed, but NightOverlay only
created the local actor's light. It now maintains a native shadow-casting beam
and glow for every survivor on every peer, using their replicated state and
safe emitter offsets. Ambient adaptation and woods sight remain viewpoint-local.
Flare replicas retain native lamps; graphical regressions verify real terrain
illumination, excluding HUD/sprites/sparks from before/after pixel comparisons.
Network rules advanced to `lnac-net-2` so both copies must update.

Verification on macOS arm64 / Godot 4.7.2:

- Two graphical peers, both modes: **177 assertions**, all pass.
- Four graphical peers, both modes: **303 assertions**, all pass.
- **14 independent ENet process runs / 480 assertions**, zero errors/warnings.
  Includes all-gear single drop, offset loot, repeated hits/120s persistence,
  mandatory kit, revive supply nonduplication, shared flashlight/flare terrain
  brightness, rescue at departure, plus prior authority/lifecycle coverage.
- Full `python3 tools/verify.py`: **75 steps passed**, zero errors/warnings,
  including required import/startup and active solo escape regressions.
- Content: **350 assertions**, all pass across six roles/both modes. Initial
  fixture failures expected retained supplies after downing; corrected to check
  starting bonuses before down, full gear drop, then no refresh after revival.
- Representative engine captures opened: centered teammate names, shared beams/
  flares and gear beside the prone player. Documentation links and whitespace
  checked before publication. No human or separate-machine Internet test claimed.

[Durable reports/logs/screenshots](evidence/rescue_lighting/README.md) and the
[connection/rescue guide](multiplayer_guide.md) record execution and limits.
Voice remains a separate future feature; no microphone changes.

## 2026-10-16 — ENet host/join co-op in Quick Camp and Woods Expedition

Following published rendering/denser-roaming commit `3bc1203`, implemented
1–4 survivor listen-server sessions with a dedicated name/role/address/UDP-port
lobby, Host/Join, ready/unready, host mode/seed selection, Settings/music and
clear connection/running-camp/host-loss messages. Default UDP port is 27840.
Rules/role changes clear ready. The host validates version/allowlisted choices,
locks seed/participants/round identity and waits for all worlds to load. Duplicate
roles remain allowed. New joins are lobby-only; no active-round supply refresh.

A persistent `Net` RPC endpoint receives only sequenced normalized finite
movement/sprint/hold controls and allowlisted rate-limited actions. The host owns
actor physics, role bonuses, damage/bleedout/revive, AI/powers/projectiles,
pickups/site rewards, supplies, ignition/boarding/countdown and results. One
actor owns each hold and switching resets progress. Clients disable outcome
physics and render/interpolate plain host snapshots of actors/NPCs/animation,
items/dropped units, sites, van, flares, hex bolts, slow patches and tin lures.
Temporary entity IDs, input, assembly and replica state are cleared on replay.

The initial graphical woods test exposed compressed snapshots above the UDP
MTU. Corrected this with 1000-byte payload pieces, bounded one-sequence assembly,
stale/duplicate/incomplete rejection and 64KiB compressed / 1MiB decompressed
limits. A real-RPC regression deliberately omits pieces and proves the next
complete state recovers. Transient dropped units are recycled so repeated
pickup/drop cycles do not expand snapshot state indefinitely. Local Esc menus
stop that player's controls without pausing the world. Corpses/disconnecting
survivors release objective inventory once; actors/passengers are removed cleanly.
The host's results replay returns everyone to an unready lobby with optional
same-seed retry. Host loss ends clients cleanly; no host migration.

Added teammate name labels, replicated animation/AI-target metadata for correct
local cues/heartbeat, nearby survivor footfalls and host-only replay controls.
Stable peer/round IDs, host-owned positions/life states and separated reliable
control / ordered-unreliable input/world channels prepare the next voice feature.
No microphone, permission prompt, codec, media transport or voice capture is
implemented. Local replicated-source audio is not the exactly-once synchronized
sound-event/listening gate.

Verification on macOS arm64 / Godot 4.7.2:

- Two-peer headless camp + woods: 153 assertions, all pass, including late joins.
- Four-peer headless camp + woods: 255 assertions, all pass.
- Two actual graphical windows in both modes: 153 assertions, all pass; lobby,
  host and client PNGs opened and visually inspected.
- Four graphical Camp windows: 124 assertions, all pass.
- Total: **24 process runs / 685 network assertions**, zero errors/warnings.
  This includes real Host/Join callbacks, readiness/rule reset, two-way movement,
  contested pickup, forged role/action/nonfinite input rejection, shared injury/
  revive, no bonus refresh, dropped-item/flare/hazard replication, remote mechanic
  ignition, all-peer boarding/extraction, retry, death/disconnect objective
  recovery and host loss. Host fixtures isolate these rules; no human co-op run
  is claimed. Largest snapshot payload is 1000 bytes.
- `python3 tools/verify.py`: **75 steps passed**, no errors/warnings; solo round,
  current 49-enemy expedition, native navigation/visibility, audio and lifecycle
  regressions remain runnable. Final content regression after drop recycling:
  **326 assertions, zero failures**. Final required import/startup passed.
- Final graphical content: **344 assertions**; menu: **39 assertions**, both
  zero failures. Corrected theme-inherited button sizing, selection-card heights,
  belt/location spacing and the four-row lobby. Refreshed README/guide images.
  The first four-window run exposed a test assumption that an unreliable packet
  must arrive; retrying the same incomplete piece fixed the harness while retaining
  the partial-state rejection/recovery assertions. The final four-window run passed.
- Documentation links/image paths/heading anchors and `git diff --check` checked
  before publication. Remote fetched; preserve remote history when publishing.

[Connection guide](multiplayer_guide.md), updated README/brief/architecture/
voice design, and [durable evidence](evidence/multiplayer/README.md) distinguish
implemented routing from acceptance. A real separate-machine LAN/Wi-Fi or
cross-network Internet/VPN round, human balance, jitter/high latency,
Windows/Linux/exports and synchronized-audio/voice gates remain unverified.
Direct Internet hosting requires reachable UDP routing or an existing virtual
LAN; no automatic NAT traversal, relay or matchmaking was added.

## 2026-10-16 — Retain survivor textures, clean belt labels and denser roaming threats

Fixed selected survivors rendering as white rectangles by retaining the role
Texture2D on the actor instead of loading/releasing a temporary resource in
`_draw`. Added actual SubViewport pixel checks for all six roles; the graphical
run passed 13 assertions, including the belt text check. Belt slots retain their
selection key and supply name but no longer append quantity numbers.

Added original Relay Jackal, Ration Moth and Lens Eater sheets/behaviors away
from biome guardians. Seeded expedition population increases from 24 to 48
cryptids (16 species) plus the stalker, with 24 additional roamers around camp
approaches, outside camp and landmark footprints. Jackals flank visible actors
and search longer, ration moths investigate ration-use noise, and lens eaters
warn before a capped beam-facing light drain. Flares now cancel pending powers/
charges, preserving the existing counterplay. Maintenance supplies three flares.

The first denser fixed-seed bot escape failed after exhausting its flares. After
correcting charge/flare interaction and adding the preparation stash, the
ordinary-input expedition passed: 200 assertions, all 49 enemies active,
12,501px walked and one flare left. No AI disabling or player teleports in that
playthrough. Human difficulty balance is still unrecorded.

Required headless import/startup passed. Full `python3 tools/verify.py` results
are preserved in the denser-forest report; focused graphical content passed
343 assertions, map/navigation tour 113, survivor pixel rendering 13, all zero
failures. Updated the README's monster explanations, full map, biome and belt
images, current count references, brief and asset provenance. Captures were
opened for visual inspection; links and `git diff --check` checked before
publication. [Evidence](evidence/denser_forest/README.md) records commands and
limits. Networking implementation follows as a separate increment.

## 2026-10-16 — Refresh the full-map example for the nine-region forest

Replaced the README's earlier three-region atlas with an actual Godot capture
of the current Night 42 recipe. The overview now numbers all nine regions,
color-codes their footprints, labels each optional region's guardian and the
three required-cache regions, and shows central Fernwood camp plus the current
24 cryptid spawn positions. The original finite world bounds, seeded maze and
2,410 clearings are drawn directly from the current world recipe. No gameplay
rules changed; the full atlas is an inspection example, separate from the
explored-only field map. Historical evidence remains unchanged.

Updated the README, content guide and screenshot/evidence notes. The new
[full-map image](evidence/content_expansion/full_map.png) was opened and visually
inspected for readability, alignment and complete world framing. Godot 4.7.2
macOS arm64 required headless import/startup exited 0 without errors/warnings.
Graphical `surround_world.gd -- --capture` with Dummy audio exited 0:
**89 assertions, zero failures**, including nine region centres, current creature
homes, connected forest cells and all four camp exits. Preserved
[raw execution](evidence/content_expansion/full_map_graphical.log) and appended
the [report](evidence/content_expansion/summary.json). Local links/image paths
and `git diff --check` passed. Fetch/push the authorized origin/main and confirm
the remote commit. Human balance, other platforms and online gates are unchanged.

## 2026-10-16 — Complete the README player guide and illustrated content gallery

Corrected the incomplete player-facing documentation from the prior content
increment. The README had linked to a separate content page while its main
monster table/site guide/gallery still omitted the new additions and retained a
six-species claim. The main guide now covers the stalker and all 13 cryptid
species, including habitat, warning/attack timings, light/flare responses,
roaming versus territorial pursuit and counterplay. All nine major regions now
have directions, landmarks, reward/risk and approach explanations. Added exact
six-role bonuses, rare consumables, belt-full behavior, and accurate replay flow.
Updated the current verification summary instead of presenting the older full
graphical baseline as the latest content report.

Embedded all six existing new-biome screenshots directly into the README,
alongside the belt capture. Extended only the graphical art tour to capture
seven new monster close-ups at native gameplay zoom. Bright ambient, disabled
AI/sight masking, hidden camper and disabled player lights are explicit inspection fixtures;
no combat or human-play evidence is claimed. All seven unedited viewport PNGs
were opened and visually inspected. The game rules are unchanged.

Verification: Godot 4.7.2 macOS arm64 headless import and five-frame startup
exited 0 without errors/warnings. Graphical `content_expansion.gd -- --capture`
with Dummy audio exited 0: **316 assertions, zero failures, 15 captures**.
Documentation links/image paths and local heading anchors were checked, guide
rules compared with the implemented roster/AI/hazards/layout/items, and
`git diff --check` passed. Preserved [guide run](evidence/content_expansion/guide_graphical.log)
and appended the [report](evidence/content_expansion/summary.json); prior execution
evidence remains intact. Human balance and online/cross-platform gates remain
unverified. Fetch before publication; publish this documentation/capture increment
to the authorized origin/main and confirm the remote commit.

## 2026-10-16 — Offline survivors, item belt and six landmark biomes

Implemented the user's priority amendment: substantial player/monster/biome
content before online multiplayer. The brief is now 1.6. Six survivor cards have
animated original outfit previews, exact bonuses, saved allowlisted choice,
keyboard/mouse navigation, Back/Start, independent Random Survivor and Settings.
Private per-player configuration applies spawn supplies once. Jock/Grease Monkey/
Scout/First-Aid Kid/Quiet Kid/Overprepared bonuses now affect their documented
stamina, ignition, light, rescue, sprint hearing and supplies. HUD uses effective
stamina and interaction thresholds; changing the ignition/revive actor resets work.

Added a six-type supply belt with same-type stacks, 1–6/keypad selection, a
visible held supply, V use, G whole-stack drop and E single-unit recovery.
Required car parts and reusable cutters stay separate. Full belts reject new
types without consuming pickups/rewards. Noise tins emit three delayed rattles;
salt wards protect from physical hits for four seconds; glow moss restores 35
light charge and clears hexes. Existing Q/R/C shortcuts and teammate medkits remain.

Added Flooded Mill, Bramble Orchard, Starless Observatory, Last-Car Rail Yard,
White Stone Quarry and Drowned Chapel: nine major regions total, six small ruins,
unchanged finite world size and required-cache recipe. Connected open-loop
footprints preserve multiple approaches, 32px aprons and objective navigation.
Native pixel scenery includes waterwheel/boiler gauges, channel bridges, trellises,
fruit trees, dome/telescope, track switches, quarry terrace/ladder markings, broken
columns/candle pews and chapel mosaics; bog dressing covers its expanded area.
These optional first versions do not implement all interiors, hazards, quests or
seeded module variants from the design backlog. Dressing is walkable.

Added seven original directional cryptid sheets and first behavior versions:
Switchback Hound, Stoneback Ram, Bramble Seamstress, Shutter Wraith, Candle Grazer,
Boiler Saint and Last-Car Conductor. Hounds use longer hearing/search and locked
telegraphed charges; six landmark guardians reject targets/stimuli outside their
zones and constrain destinations. Wraiths stop under a visible beam, grazers
consume nearby visible flares, and other guardians mark bounded expiring slow
patches/charges. Patches never edit collision or lock routes. Population remains
24 cryptids across 13 species plus the stalker. Existing cryptids/stalker receive
trim/seam detail. New species reuse the registered revenant call with existing
proximity limits; no bespoke new audio assets or microphone access is claimed.

Verification on macOS arm64 / Godot 4.7.2:

- `python3 tools/verify.py`: exit 0; **69 steps passed**, zero errors/warnings.
  Includes import/startup, all script parsing, native navigation/region homes,
  shadows/sight, local audio, replay, full keyboard-driven camp win/loss and
  expedition escape with all enemies active.
- Final required headless `--import` and five-frame startup: exit 0, no errors.
- Final focused headless content: **301 assertions, zero failures**; forest hunt:
  **80 assertions, zero failures**; woods visibility: results in preserved log.
- Graphical content with Dummy audio: **309 assertions, zero failures**; actual
  engine screenshots opened and inspected for selection, held supply/belt and
  all six biomes. The biome tour brightens light/disables sight for inspection;
  the belt capture retains ordinary night lighting. No human playthrough claimed.
- Documentation links/assets checked against disk and implemented rules;
  `git diff --check` passed. Remote fetched before publication, with no divergence.

Checks cover role values in both mode flags, real drain and ignition boundaries,
nonduplication/private stats, selector/settings, keypad/number input, full belt,
drop recovery, rare consumables, locked/expiring powers, region nonoverlap and
multiple entrances, and guardian limits. Fixed legacy test assumptions about
immediate replay, six-only species and every non-village site being a cauldron.
A review also found sprinting interactions incorrectly receiving Quiet Kid's
modifier; separate sprint/environment stimulus signals now preserve full cache/
flare hearing even while sprinting, with explicit regression coverage.

[Content rules and screenshots](content_update.md),
[verification report](evidence/content_expansion/summary.json) and selected raw
logs/captures in [content evidence](evidence/content_expansion/README.md) are
preserved. Human normal-speed balance, full all-role input-only escape rounds,
Windows/Linux, exports, multiplayer/synchronized audio and proximity voice remain
unverified. Actor/teammate fixtures do not pass M1-S human or co-op gates.

## 2026-10-16 — Markdown-only survivor, monster and biome planning

Updated planning in response to the survivor-selection, expanded-monster and
detailed-biome requests. [Survivor/co-op plan](survivor_multiplayer_plan.md)
defines a pre-game selection flow and six original camp archetypes: Jock,
Grease Monkey, Scout, First-Aid Kid, Quiet Kid and Overprepared One. Proposed
personal advantages support stamina, ignition, lighting, rescue, stealth and
supplies. Includes exact initial values, solo/duplicate-role viability,
private configuration, one-time application, authoritative lobby/ready lock and
staged M1-S → M2 → M2-A → M3 → M3-V → M4 delivery/acceptance.

[Monster catalog](monster_catalog.md) adds **48 distinct concepts**, each with
trigger, nearby visible/audio tell, counterplay, limits and habitat. Covers
pursuit, perception, sound deception, terrain, resource pressure and landmark
guardians, plus compatible/prohibited pairings and first prototype gates.
The seven existing enemy designs make 55 designs in total; the current spawn
population is unchanged. Mimic powers use authored cues, not captured speech.

[Biome design](biome_design.md) details **18 regions**: expanded current
graveyard/village/bog and **15 new pockets** in the existing giant maze. Every
dossier specifies identity, internal routes, optional interaction/reward,
threat/counterplay, seeded variation and checks. Shared rules reserve entrances,
loops, aprons and coherent collision/nav/shadow/sight; retain the current required
regions and five-part recipe. Proposed first slices are Flooded Mill/Boiler
Saint, Orchard/Bramble Seamstress, Observatory/Shutter Wraith and Rail Yard/
Last-Car Conductor. No full-catalog requirement before voice or distribution.

Updated authoritative brief to **1.5**, milestones, audio/voice design, README,
architecture and testing. The user's latest amendment removes the Word brief:
deleted `last_night_at_camp_agent_brief.docx`, changed AGENTS.md and active
documentation to maintain Markdown only. Historical log/evidence entries about
earlier Word checks remain historical; there is no ongoing Word alignment or
rendering requirement.

**Verification:** required Godot `--headless --path . --import` and
`--headless --path . --quit-after 5` both exit 0 with zero errors/warnings on
macOS arm64/Godot 4.7.2. Checked **90 local links/anchors and 23 PNG references**
across 17 Markdown files,
unique/complete IDs for all 6 roles, 48 new monsters and 18 biomes, current
rule values against player/config/van/world scripts, and `git diff --check`.
Reopened the existing Settings and surrounding-world screenshots to check the
documented baseline; no new gameplay screenshots or results are fabricated.
Raw command/document-check output is in ignored `artifacts/planning_verification`.

This is a documentation-only increment; no runtime scripts/assets changed.
The prior 77-step gameplay report remains the latest full regression, not a new
run. Selection/bonuses, new monsters/biomes, networking and voice remain planned.
Human balance/listening, Windows/Linux/Intel Mac, exports and real microphone
permission/online tests remain unverified. No microphone capture is introduced.

## 2026-10-16 — Massive forest around central camp and spacious region approaches

Completed the same request after the verified sight/audio/Settings increment
`ae1c5b0` was published. World is now **9600×9408**, centred exactly on the existing
camp at (768,480), with **2410 connected forest clearings**, four camp exits and
128px trails. Forest area is about 35× the former 1600×1600 woods. A finite
50×49 grid excludes the 40 central camp cells; loops and seeded approach routes
connect northwest village, east bog and south graveyard without flattening the
deep outer maze. Village is 960×576; bog/graveyard each 768×768 with clear 32px
aprons. Huts, required cache and props use the expanded layout; bog has a long
boardwalk and graves leave a clear central approach.

24 cryptids (four per species) populate near and deep rings on all four sides,
with 16-waypoint roaming routes, alongside the stalker. Added 96 seeded forest
supplies. Camera limits, light drain, fog, labels, sensing and local chart handle
all directions/negative coordinates. Field notes pan over explored nearby trails
and indicate camp direction. Quick Camp keeps its three-part objective. The
previous sight mask, near-only creature calls and menu Settings remain active.

32px occupancy provides constant-time terrain lookup and merged collision/shadow
spans. Forest scenery renders only around the camera, at native art detail;
quantized view/focus updates avoid regenerating all drawing each frame. Camp
retains native TileMapLayer and all collision/AI remain active across the world.

**Failures resolved:** a giant single navigation polygon occasionally failed
convex partition on random seeds. Bakes now use 49 bounded native regions with
7px clearance and 16px edge connections. Explicit synchronous initial map/region
updates avoid querying an unfinished asynchronous merge. Twelve deterministic
seed stress runs check every pickup and four exits. Door checks allow the native
7px seam projection; real input still traverses collision. Density fixtures now
check solid forest mass rather than thousands of obsolete sprite nodes. Dense
region links needed a 16-point route to retain patrol spread. Inspection captures
use exact quarter scale to avoid nearest-neighbour minification moire.

**Final verification:** `python3 tools/verify.py --graphical` exit 0, **77 steps**,
zero engine errors/warnings. Required import/startup/all parses, fourteen suites
headlessly (one stress suite headless only) and thirteen graphical suites pass.
Surrounding-world checks: 55 headless / 59 graphical assertions. Woods replay:
413/429; camp layout: 1009/1011 across eight seeds, every door/pickup reachable.
Region/AI/spell checks: 56/61. Full woods expedition: 192/193 assertions; all 25
enemies active, five parts collected/installed through input, two real stashes
used, about 12,499px/38 clearings traversed and successful extraction. Normal camp
escape/loss/restart also pass. Sight, four border-light probes, native MP3 decode/
loops, nearby cues, menu Settings/random defaults and lifecycle cleanup pass.

Opened/inspected final whole-world schematic, enlarged village/bog/graveyard,
normal woods light, local field notes, masked/unmasked sight and active escape.
[Full report](evidence/surround_forest/summary.json),
[evidence notes](evidence/surround_forest/README.md). Final region-only refresh
passed 59 assertions; import/startup rechecks were clean. Source audio hashes are
unchanged; documentation links/images and `git diff --check` pass. All 54 Word
requirements match Markdown. DOCX render attempt again failed on missing
`pdf2image`; LibreOffice is unavailable, so Word visual QA remains unverified.
macOS arm64/Godot 4.7.2 only. Human balance/listening, Windows/Linux/exports and
networked audio/gameplay/voice acceptance remain open. No microphone capture.

## 2026-10-16 — Opaque woods sight, nearby creature cues and menu Settings

First verified increment of the new forest-surround request. Added a 256-ray,
260px opaque world mask and whole-monster sight gating. Hidden terrain stays
black even in fully bright ambient light; visible HUD species cues follow sight.
AI remains independent. Calls start within 160px and enemy steps within 110px;
native quadratic attenuation follows moving sources through weak references.
Menu mixer is behind Settings, with saved gain and uninterrupted menu music.

`python3 tools/verify.py --graphical`: 71 steps passed, zero errors/warnings;
full active camp/woods escapes, import/startup/all parses, 4 headless / 7 graphical
sight/proximity assertions and 20/21 menu checks. Rendered bright-ambient paired
controls prove the mask hides the adjacent path and whole monster, rather than
relying on darkness. Native emitter range/follow checks pass. Existing lighting
and overview fixtures explicitly disable the new mask only for isolated QA.
Inspected menu/Settings and masked/unmasked captures.
[Report](evidence/sight_audio/summary.json). Markdown/Word requirements aligned,
source audio unchanged. Human listening, Windows/Linux/exports/network/voice and
Word visual rendering remain unverified as previously documented. The much larger
central-camp forest and spacious region transitions are the next increment in
this same authorized task; they are not claimed complete here.

## 2026-10-16 — Menu music/mixer, random-default camps and opaque woods borders

**User amendments:** music/volume knobs on the menu before Play, random by
default, and no flashlight spill onto paths beyond the bordering trees. Updated
Markdown/Word requirements, player documentation, architecture and testing.

Menu owns ominous music and subdued forest ambience with the shared saved
Master/Effects/Ambience/Music controls. Controls browsing keeps audio playing;
scene departure stops/frees it before round audio starts. Normal Quit drains
native audio-thread stop commands before shutdown. No microphone/network change.

Random Night is checked on every menu load and ignores/disables the seed field.
Both Quick Camp and Woods Expedition now randomize camp buildings; wider 16px
offsets and compatible bunk/bath-first-aid lot swaps make changes clearer. Loot,
doors, lights and map markers follow the same recipe. Placement rejects other
door approaches as well as roads/roofs/water. Ordinary starts and Another Night
use fresh seeds in both modes, avoiding immediate seed repeats. Explicit seed
entry and Retry This Seed preserve reproducibility. Quick Camp retains three
components and its original sensing values, not fixed building coordinates.

Solid woods collision spans now also cast full native light shadows. Small
trunk silhouettes alone previously allowed beams across neighboring paths.
Flashlight/nearby-glow offsets ray-clamp on the player's side of collision so
hugging a border cannot place a head-height light beyond it. The current path
remains illuminated; adjacent disconnected paths receive no flashlight light.

**Verification:** final `python3 tools/verify.py --graphical` exit 0: **67 steps**,
zero engine errors/warnings. Required import/startup and all GDScript parses pass;
eleven suites pass headlessly and graphically, including complete active-enemy
camp/woods escapes and all 14 audio decode/seven loop checks. Menu/defaults: 17
headless / 18 graphical assertions; shadow suite: 2 headless / 12 graphical;
eight seeded camp checks: 369 headless / 371 graphical. Zero assertion failures.
Menu/default tests execute actual menu starts in both modes, mixer mute/saved
gain before Play, new camp/seed on Another Night, explicit seed and same-seed
retry, and free/recreate menu audio ownership. Isolated preferences are restored.

Four pixel probes across horizontal/vertical blocked trail links measured
current-path flashlight luminance gain about 0.415–0.429 and adjacent-path gain
**0.0**. Turning off border shadows in the positive control reproduces adjacent
spill of 0.154–0.184, proving the probe is inside the beam. Full native border
polygons and safe emitter offsets also pass headlessly. Opened/inspected menu
knobs/default option, blocked/unblocked border captures, both seed overviews,
campsite/lodge, woods light and successful expedition outcome.

**Iteration:** initial graphical fixture required explicit Vector2 declarations.
Native MP3 playbacks produced shutdown leak warnings when the engine/test quit
immediately after stopping menu or round loops. Normal Quit and test exits now
use the same graceful stop/drain, and stopping round playback disables its audio
update so loops cannot restart during shutdown. Final run has zero warnings.
Decoder fixtures stop menu loops before per-file PCM measurements to avoid
ambience contamination. Legacy rule fixtures now use current seeded building/
loot coordinates; gameplay rules and active enemies were not weakened.

[Full report](evidence/menu_shadows/summary.json),
[evidence/limits](evidence/menu_shadows/README.md). Links/images, asset hashes
and `git diff --check` pass. All 54 Markdown requirement bullets match the Word
brief; XML/namespaces check structurally. DOCX render retry remains blocked by
missing `pdf2image`/LibreOffice; Word visual QA unverified. macOS arm64 / Godot
4.7.2 only. Human listening/balance, Windows/Linux/exports and network/voice gates
remain unverified.

## 2026-10-16 — Offline supplied audio, adaptive heartbeat and saved mixer

**Scope:** continued the visual/audio-first amendment after publishing the layout
increment `354ca4e`. Integrated all 14 user-supplied MP3s, including the vampire
snarl added during work. No downloaded/generated replacement audio, networking
or microphone capture. Original MP3s remain byte-identical; manifest records cue
IDs, hashes, durations, bus/loop/gain settings and pending source/license details.

**Playback:** round-owned forest/bog crossfade, positional campfire, restrained
music, indoor footsteps, outdoor sprint loop and distance-based walking/enemy
steps. Heartbeat smoothly rises when any enabled enemy actually sees this player
and chases, then fades after target loss; it never changes AI sensing. All six
creature species have appropriate named calls on alerts/nearby activity; witch
wind-up shares the per-source cooldown to prevent stacked cackles. Twelve-voice
positional pool and seven loop channels are bounded. Surface/collision/boarding
stop movement sounds; pause suspends playback; results stop it; scene replacement
frees loops/voices/listener. Headless/no-output operation remains playable.

Master/Effects/Ambience/Music sliders fit the pause panel and save preferences;
zero mutes. Voice bus is reserved/inactive. Peak/mean analysis revealed large
recording level differences, especially the fire's ~43dB crest factor. Per-cue
gains, a fire compressor routed through Ambience, and master limiter keep detail
audible while bounding peaks. These are initial measured settings; final comfort,
loop seam quality and balance still need human listening.

**Verification:** `python3 tools/verify.py --graphical` final exit 0: **60 steps**,
zero engine errors/warnings; import/startup and every script parse, nine suites
headlessly and graphically, including complete active-enemy camp/woods escapes.
Audio suite: **46 headless / 68 graphical assertions, zero failures**. Actual
MP3 decoding and nonzero gain-staged PCM verified for all 14 files through their
native mixer buses/effects using Dummy output; all seven native loops wrap after
seeking across the end. Checked mute persistence, all six species/cooldowns,
heartbeat attack/release, floor/sprint selection, bog crossfade, bounded voices,
pause/resume, no-device handling, results, retry/menu cleanup and mute-independent
AI hearing. Normal graphical gameplay suites use the platform output driver,
but no human listening session is claimed. Eight-seed native layout checks still
pass 361 headless / 363 graphical assertions.

**Iteration:** initial audio test had an unsupported driver-query API and an
inferred WeakRef parse error; corrected to the installed API/explicit type.
Headless streams never start, so their paused flag cannot demonstrate suspension;
the fixture now tests rejection/no-device behavior there and real suspension
with output active. Full regression exposed fixture enemies added after round
initialization; soundscape now registers new enemies and prunes stale IDs safely.
Final decoder test drains stale samples between cues and taps each real cue bus,
including fire compression, rather than attributing previous-cue tails to a file.

Opened and inspected final pause mixer, field guide, both camp layouts, campsite,
field notes and escape/woods views. [Full report](evidence/audio_polish/summary.json),
[coverage/limits](evidence/audio_polish/README.md). All 14 MP3 hashes match the
manifest, local Markdown links/images resolve, and `git diff --check` passes.
Markdown/Word briefs aligned; all 54 requirement bullets match, all DOCX XML
parses and compatibility namespace declarations are present. DOCX render retry
failed because `pdf2image` is absent; LibreOffice is unavailable, so Word visual
QA remains unverified. macOS arm64 / Godot 4.7.2 only. Human listening/balance,
Windows/Linux, exports, synchronized audio and network/voice gates remain open.
No microphone permission is requested; future voice must test platform permission
denial/no-device behavior without blocking gameplay.

## 2026-10-16 — Camp path fixes and seeded building lots

User amendment prioritizes visual/map fixes, camp variation and supplied sounds
before networking/voice. Updated Markdown/Word requirements and audio design;
future synchronized audio/voice gates remain unclaimed. Preserved pre-existing
project-rule/design edits as part of this requested amendment.

Rerouted the north trail below Cedar and west of Maintenance, shortened the mess
hall footprint to clear the middle trail, and reserved road/roof/door space.
Woods Expedition chooses seeded 16px building offsets within finite camp lots;
loot, walls, lights, roofs, door paths and chart share the recipe. Trees now
respect all building/road clearances and vary by seed. Quick Camp retains the
familiar objective buildings. No arbitrary unbounded procedural camp generation.

Verification: initial full `python3 tools/verify.py --graphical` passed existing
suites, including active camp/woods escape and graphical lighting checks. Final
`python3 tools/verify.py` runs import/startup, all scripts and all eight headless
suites on the final layout. New native layout tests: 361 assertions headless and
363 graphical, zero failures across eight seeds, every door/pickup reachable.
The first new test queried navigation before its bake completed (272 failures);
waiting for an actual route fixed the fixture without changing game rules.
Opened and inspected both seeded camp overviews, field notes and gameplay views.
[Layout evidence](evidence/layout_polish/layout_headless.log),
[graphical evidence](evidence/layout_polish/layout_graphical.log).

Initial sandbox import encountered macOS certificate/settings access errors;
required checks reran with normal host access. Word requirements structurally
match all 54 Markdown requirements and preserve existing paragraph formatting.
DOCX render attempt failed because `pdf2image` is absent; LibreOffice is also
unavailable, so document visual QA is unverified. macOS arm64 / Godot 4.7.2
only; Windows/Linux, exports, network/voice and human playtesting unverified.
Local sound integration is the next increment in this same task.

## 2026-10-15 — Forest hunt expansion: themed sites, six species and smarter AI

**Authorized scope:** continue the user's request after the separately verified
path-visibility fix (`27d6c77`, pushed to GitHub). Keep the same world bounds and
finite trail maze while adding larger, usable areas, more discoverable monsters,
intelligent sensed behavior, a Sasquatch redesign, vampire/witch and another
fitting creature. No networking or distribution milestone is claimed.

**Areas/objectives:** opened a 416×256 abandoned village and two 256×256 bog/
graveyard clearings, with matching internal trail links. Village has two furnished,
enterable huts with roof cutaways and native walls. Each themed site now holds
one of the three required woods caches; battery/key and the five-part repair
rule remain. Generated supplies avoid hut walls. Kept all six smaller landmarks.
Added stone square/well/bell, marsh planks/cauldron, crypt/headstones/fencing and
small localized lamps. Bounds remain 3456×1920; most of the woods remains maze.

Village bell is a reusable location-based distraction with a 12s cooldown and
1100px event range. The well yields two flares, a battery and rations once. Bog
cauldron refills the flashlight once but applies a 2s hex. Crypt gives two flares
once. Claims validate living actor membership, proximity, clear access, pause,
cooldown and availability. Pickups and stashes make AI noise events at the item,
not at an unsensed player's later location. Audio remains unimplemented.

**Creatures/art:** each expedition now spawns four different cryptids: vampire
and witch plus two selected from wolf, Sasquatch, moth and briar revenant, alongside
the stalker. Revised Bigfoot into a tall hunched ape with a crested skull, small
sunken face, sloping shoulders, shaggy fur, long arms/fingers and large feet.
Original vampire has a high collar/pale face/cloak; witch a pointed hat/braid/
staff; antlered briar revenant twig limbs/ribs/moss. All six use 64×64 directional
walking sheets, reproducible with the standard-library art tool. No external
assets, packages or image service were used.

**Intelligence/encounters:** moved expedition stalker toward traveled camp routes
and increased its sight/hearing before weather modifiers. Cryptids traverse
branching eight-waypoint circuits near objective areas, replacing tiny home
patrols. Native projection prevents obstructed goals from leaving enemies stuck.
Visible-target lead uses current sensed movement and wall checks. Lost-target
search sweeps the last sensed location and four nearby reachable points, keeping
hidden positions out of destination updates. Visible flares cause a faster
retreat. Vampire slows/flanks in an aligned flashlight beam; revenant senses
motion unless very close. Quick Camp retains its original spawn/sensor values.

Witch keeps ranged distance and telegraphs a 0.8s wind-up, locking aim before a
fixed-trajectory projectile with a 3.2s firing cooldown. Losing sight or seeing a
nearby flare cancels casting. Bolts move 104px/s, expire within 2.5s, and use swept
wall/player checks. They can be dodged; walls absorb them. A hit causes a 1.6s hex
at 60% movement speed and drains 1.5 stamina seconds, not instant downing. Violet
ring and priority HUD timer explain the effect. Pause freezes casting, hazards
and actor hex timers; restart/menu replacement clears them.

Updated README (including current creatures/areas screenshots), field guide,
architecture, testing and milestones. Woods chart outlines discovered site areas.

**Failures/iteration:** early tests incorrectly applied wolf-only expectations to
new species; kept legacy species checks separate and added dedicated new behavior
fixtures. A legacy cabin-navigation assertion expected the killer to remain at
its destination after four seconds; the smarter search had already left. It now
asserts actual arrival during the bounded traversal. Early bots wasted flares
on nearby but repelled/unseeing enemies, then ran into vampires or the returning
stalker. They now use normal input to search the well and crypt, conserve flares,
react to nearby searching threats and use existing rations. Quick Camp's bot also
uses its existing supplies and follows native segments with correct input
strengths. Both full playthroughs keep production rules active and award items
through ordinary input; isolated rule fixtures deliberately place actors and
set state to inspect individual behavior.

Rendered review caught a dark caster shot and fixture enemies re-enabled by pause
resume. Lit/recomposed the isolated shot and explicitly restored fixture isolation.
Site overview cameras use 0.75 zoom only for evidence; normal gameplay stays at 1.
The village huts remain physically enterable and objectives are reachable.

**Verification:** `python3 tools/verify.py --graphical` final exit 0; all 50 steps
passed, with zero engine errors or warnings. Import/startup and every GDScript
parse passed. Seven suites run headlessly and in actual graphical windows.

| Suite | Headless assertions | Graphical assertions | Failures |
| --- | ---: | ---: | ---: |
| Menu | 37 | 39 | 0 |
| Offline rules | 60 | 66 | 0 |
| Quick Camp active rounds | 108 | 113 | 0 |
| Camp layout/boarding | 31 | 44 | 0 |
| Seeded woods/navigation/art | 213 | 229 | 0 |
| Five-enemy active expedition | 162 | 163 | 0 |
| Sites, AI and spells | 36 | 41 | 0 |

The active expedition collected all five parts and used the two real site
stashes through E, traveled about 9,940px/32 clearings, installed parts, boarded
and escaped with all five enemies active. Native fixtures also verify actual
patrol movement, both hut interiors, no duplicate rewards, bell stimuli/cooldown,
cauldron trade-off, vampire beam/flank, motion sensing, hidden-target memory,
wind-up/fire, blocked casting, projectile collision/dodge, pause and cleanup.
All six rebuilt sprite sheets matched SHA-256 values byte-for-byte.

Opened and inspected the final six creature shots, expanded village/bog/graveyard,
witch wind-up and bolt, field guide/notes, light on/off and active escape result.
Final report, raw logs, art hashes and captures:
[forest_hunt](evidence/forest_hunt/summary.json). Source/document whitespace and
README link/image checks passed: 41 local links and 16 embedded PNGs resolve.
Final art reimport and five-frame startup each exited 0 without errors/warnings.

**Limits:** macOS arm64 / Godot 4.7.2 only. No connected co-op, exports, other
platform execution or human real-time balance session. Seeds 42/2026 receive
physical navigation checks; eight seeds receive recipe checks; only seed 42 has
an active Woods escape test. The bot uses native paths as a route guide. Themed
props are primarily decorative around the validated huts/interactions; no claim
of a fully simulated settlement or every seed's balance. Networking remains M2.

## 2026-10-15 — Path visibility correction

First verified pass of the requested hunt expansion. Investigated dark blocks:
fog used hard rectangular screen strips, while merged woods collision spans and
legacy square tree bounds cast rectangular shadows unrelated to visible trunks.
Replaced fog strips with soft radial mist, retained collision/AI obstruction
spans but used small octagonal trunk occluders for tree shadows, and faded canopy
locally when it covers the camper. Building wall shadows remain.

`python3 tools/verify.py --graphical` exited 0: all 45 steps passed without engine
errors/warnings, including both complete active escapes. Opened the matched woods
captures: mist has no hard strip edges and illumination follows trunks.
`git diff --check` exited 0. Evidence: [path_visibility](evidence/path_visibility/summary.json).

Continuing the same request with themed sites, roaming/search AI, vampire/witch/
revenant encounters and a Sasquatch redesign.

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
