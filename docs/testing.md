# Running and verification

Use Godot **4.7.2 stable** (standard/GDScript build, not .NET) and Python 3. No
Python packages are needed. Install Godot from its official distribution and put
its executable on PATH as `godot` or `godot4`. On macOS the tools also detect
`/Applications/Godot.app/Contents/MacOS/Godot`. Override with `GODOT_BIN` if needed:

```sh
GODOT_BIN=/absolute/path/to/godot python3 tools/verify.py
```

On Windows use Python via `py -3` if `python3` is unavailable, and set `GODOT_BIN`
to the executable in your shell environment. Windows/Linux execution is unverified.
The setup is intentionally source-based until M4; no export templates are needed
to run or test M1 in Godot.

## Launch

From the repository root:

```sh
godot --version
python3 tools/run_game.py --editor
python3 tools/run_game.py
```

Or open `project.godot` in Godot and press F6 on the menu or F5 for the project.
The menu offers Woods Expedition / Quick Camp, an optional seed, Enter the Night,
Controls and Quit. Click or use Tab/arrows and Enter. Escape closes the field
guide. Enter the Night starts the selected offline mode via the loading card.

WASD/arrows walk; Shift sprints and consumes stamina; E picks up or installs
supplies; hold E to start the repaired van or revive a nearby downed teammate;
F toggles the flashlight; Q throws a flare; R consumes a spare flashlight battery;
C consumes rations; Tab toggles notes/map; Esc pauses. Teammate revive is
implemented and fixture-tested, but there is only one human survivor in M1.
In Quick Camp, Tab opens the pack and field map with numbered locations: battery in the
Fern bunk cabin, fuel in Maintenance, key in the Ranger Lodge. Building doors face
south; roof cutaways reveal furnished interiors. Deliver all parts at the rear
of the van and hold E for two seconds. This automatically boards the driver and
displays YOU ARE ABOARD. Other living survivors press E beside the running van
to enter during the eight-second departure countdown. Passengers cannot move out
or be hit. Survivors who stay outside are left behind even if they stand nearby.
A first killer hit downs you indefinitely; repeated hits/time do not kill.
All gear drops beside the body, medkits are mandatory to revive, and a teammate
van escape also rescues downed players. All-down is defeat.
Solo has no self-revive. Woods Expedition instead requires five parts, including
three locked woods caches opened with boltcutters from Maintenance. Tab reveals
woods trails as you explore. Torch charge drains in the woods; collect spare
batteries, flares, food and medkits. Fog shortens sight/beam; rain muffles hearing.
Results offer a new seed, retry same seed, or menu return. Retrying starts with
fresh actors/inventory, not a saved checkpoint.

## Repeatable checks after changes

```sh
python3 tools/verify.py
python3 tools/verify.py --graphical
```

The second command also opens a real Godot window, exercises the menu through
keyboard input, runs mechanic fixtures and complete input-driven win/loss rounds,
captures screenshots, then exits. It requires a desktop session. Inspect the PNGs;
headless success alone is not visual evidence. Fixed 60 Hz and disabled VSync
allow automated playthroughs to run faster; normal gameplay uses real time.
The runner records each exact command, exit status, errors and warnings separately
in `artifacts/verification/summary.json` and raw per-step `.log` files. It fails on
nonzero exit, engine `ERROR:` output even with exit 0, timeout, missing test summary,
or failed assertions. Warnings remain visible in the report for review.

Equivalent individual commands:

```sh
godot --headless --path . --import
godot --headless --path . --quit-after 5
godot --headless --path . --script res://scripts/ui/main_menu.gd --check-only
godot --headless --path . --script res://scripts/ui/menu_backdrop.gd --check-only
godot --headless --path . --script res://tests/integration/menu_smoke.gd --check-only
godot --headless --path . --script res://tests/integration/menu_smoke.gd
godot --path . --script res://tests/integration/menu_smoke.gd -- --capture
godot --headless --path . --fixed-fps 60 --disable-vsync --script res://tests/integration/offline_slice.gd
godot --headless --path . --fixed-fps 60 --disable-vsync --script res://tests/integration/offline_playthrough.gd
godot --path . --fixed-fps 60 --disable-vsync --script res://tests/integration/offline_playthrough.gd -- --capture
godot --headless --path . --fixed-fps 60 --disable-vsync --script res://tests/integration/woods_replay.gd
godot --headless --path . --fixed-fps 60 --disable-vsync --script res://tests/integration/woods_playthrough.gd
```

Godot writes its normal user data and editor caches outside the repository. In a
restricted agent sandbox those writes and graphical sessions may need approval;
do not interpret a zero process exit as success when engine errors were printed.

## Coverage and limits

`menu_smoke.gd` checks boot, every physical key binding, viewport/filter settings,
keyboard focus, Controls/Back/Escape, and enabled solo Play.

`offline_slice.gd` uses explicit isolated placements to test real movement,
collision and cabin entry, stamina, proximity/availability/occlusion checks,
delivery and interrupted start holds, extraction, restart cleanup, killer
sight/hearing/memory/navigation, attack cooldown, timed revive/grace, repeat-hit and
elapsed-time down persistence. Teammates are fixtures, not connected human clients.

`offline_playthrough.gd` starts at the real menu and uses normal input only.
It walks to all three supply buildings with collision enabled, collects/delivers every
part using E, sprints to escape a real chase, starts the van, wins, restarts,
walks onto the patrol route for a loss, then returns to the menu. The killer and
default rules remain active throughout; no teleports or health/objective edits.
This is automated playability evidence, not a claimed human playtest.

`camp_upgrade.gd` verifies the larger map and entrances/objectives are reachable,
roof cutaway/restoration, automatic and explicit boarding, rejected distant/downed
or duplicate boarding, passenger safety, and escaped/left-behind results. Multiple
survivors are fixtures. Its graphical tour captures interiors, campsite, shore,
field map and character art. A matched flashlight on/off probe verifies dark
terrain brightens in the beam; this sample does not measure the whole map.

`woods_replay.gd` verifies eight seeds for reproducible topology/loot/encounters,
100 connected clearings, six landmarks, one of each of five required parts,
tools/supplies and roster/weather variety. Seeds 42 and 2026 bake real worlds and
check native navigation to every item/landmark. Isolated fixtures cover locked
cache/tool/proximity rules, battery depletion/refill, rations, flare placement and
pause, species sensing, flare responses, wolf charge recovery, seed retry/new run
and scene cleanup. The graphical tour captures loading, woods darkness, all six
cryptids, landmarks, notes and results. These fixtures intentionally place actors
and disable AI to inspect individual rules/art; they are not a full playthrough.

`woods_playthrough.gd` completes seed 42 through ordinary movement/interact/supply
input with production damage, speeds and all enemies active. The automated
route guide uses native paths, so it knows trail connectivity; it is not evidence
of human maze difficulty or balance across every seed. It prepares in camp,
collects all five parts, uses flares/sprint when threatened, returns, boards and
escapes. No teleports, health/inventory edits, or AI disabling occur. Both modes
run this expedition; the graphical variant saves the real escape result.

Manual acceptance still to record: launch normally, play an entire win or loss
at real-time speed, restart, and check that dark regions, prompts, and keyboard
controls feel readable. The rules suite also verifies pause during departure,
an empty van losing, and unboarded survivors being left behind. Explore each building manually
to assess comfort and visual clarity beyond these automated routes. Also verify
that the automatic driver entry and explicit E-to-board prompt feel unambiguous.

Human playtesting, multiplayer, cross-platform exports, Gatekeeper and
SmartScreen remain unverified. Host/client launch scripts and protocol
assertions will be added in M2 with an actual implementation, not stub flags.
Network acceptance must include two real ENet clients; later cover four peers,
single-award pickup races, shared downed/repair/extraction state, restart and
disconnect cleanup. Unsigned desktop release notes belong to M4.

## Forest hunt coverage

The updated woods recipe checks four distinct cryptids (vampire/witch guaranteed),
three expanded themed sites, all required items and abstract clearings in the
native bake. Clearing destinations inside furnished huts use their nearest
walkable point; item and hut entrance assertions still require exact access.
The active Woods test uses ordinary E to search the village well and graveyard
crypt as preparation; all five enemies remain active throughout the escape.
The Quick Camp bot now also uses its existing Q/C supplies when threatened.
No game damage, speed, health or inventory is edited by either playthrough.

`forest_hunt.gd` adds isolated fixtures for both hut interiors, broad patrol
coverage and actual roaming movement, finite/no-duplicate site rewards,
remote-interaction rejection, bell stimuli/cooldown, cauldron trade-off,
vampire beam/flank behavior, motion-sensitive revenant sensing, multiple-point
search without hidden-target updates, witch wind-up/fire, hex application,
swept projectile wall collision, blocked casting, dodging, pause and cleanup.
Its graphical variant captures the three sites, witch telegraph and moving bolt.
Site/creature screenshots use deliberate actor placement and camera composition;
they are distinct from the complete active playthrough evidence.

## Camp layout polish

`tests/integration/layout_polish.gd` checks eight distinct/reproducible expedition
camps, road/building reservations, native paths to every camp entrance and every
pickup. The graphical version captures seed 42 and 2026 overviews with an
inspection camera/raised ambient light; normal play retains its usual camera and
lighting. Both modes now use randomized camp lots; Quick Camp keeps its shorter objective.

## Offline audio verification

`audio_polish.gd` checks all 14 supplied files/loop flags, bus gain/mute and saved
preferences, movement/surface selection, bog crossfade, spotted/lost heartbeat,
six species routing/cooldowns, bounded voices, pause, results, retry and menu
cleanup, no-device events and mute-independent AI hearing. `--audio-test` uses
an isolated settings file that is removed afterward, preserving player settings.
The graphical variant uses Dummy output and captures actual native MP3 PCM via
AudioEffectCapture, with runtime gain and seek-across-end loop checks. It also
captures the pause mixer. This establishes decode/mixer behavior, not a human
listening session, seam quality, two-client sound or platform/export acceptance.

Playback never captures or requests a microphone. Windows/Linux and desktop
exports remain unverified. Before final mix acceptance, a human should listen to
walking/running indoors/outdoors, campfire near/far, bog boundaries, every creature
call, heartbeat target loss, mute/restore and pause/retry on headphones/speakers.

## Menu defaults and woods light borders

`menu_defaults.gd` exercises music/mixer before Play, immediate mute/saved gain,
random-default starts in both modes, changed camp on Another Night, explicit
retry/seed reproducibility, and menu/round playback ownership. Settings checks
use a temporary preferences file, then restore the player's settings.

`woods_shadows.gd` checks all solid woods spans have full shadow polygons and
head-offset emitters stay on the player's side of collision. Four graphical
probes compare flashlight off/on across closed horizontal/vertical trail links.
Each probe has a positive control with borders disabled, reproducing the leak.
These controls/teleports are test fixtures; production bounds and rules remain
active in the separate full playthroughs.

`woods_visibility.gd` verifies current-path visibility, hidden enemies behind
tree borders, nearby-only creature calls and native falloff/source following.
Graphical positive controls use fully bright ambient light and disable the sight
mask, proving that black occluded paths are hidden by sight, not merely darkness.
Menu-default checks also open/close Settings and save gain from its controls.

## Massive surrounding forest

`surround_world.gd` checks centred bounds, >30× old forest area, 2410 connected
cells across three seeds, creatures on all four sides, clear region aprons,
native paths to four exits/all homes/region centres and real movement through
each exit. Its schematic overview is labelled inspection; region overviews use
a wider camera/brighter ambient and disable sight only for layout QA.

`navigation_seeds.gd` bakes twelve deterministic worlds and checks every pickup
and all four exits. This regression covers the random-seed giant navigation
partition failure; bounded native regions explicitly synchronize before queries.
The woods replay suite checks graph connectivity for all 2410 cells and native
paths for about 120 sampled clearings, all pickups and all six remote landmarks.
Doorway navigation assertions allow the native 7px clearance at region seams;
separate actual-input traversal and complete rounds retain physical collisions.
No balance/visibility assumptions are replaced with AI disablement in the active
escape suites. Human balance and other desktop targets remain unverified.

## Planned survivor and content acceptance

The [survivor plan](survivor_multiplayer_plan.md) defines future M1-S modifier,
selection/lifecycle and all-role escape checks, then real two/four-peer authority
checks. [Monster](monster_catalog.md) and [biome](biome_design.md) designs add
future telegraph/counterplay, reservation/connectivity, hazard expiry/reward and
replication gates. None of those new features has implementation or test evidence
yet; existing M1 suites do not establish their acceptance. Voice still requires
opted-in real microphone and separate-machine permission/routing tests.

For this documentation-only amendment, import/startup, local links/PNG references,
current screenshot/rule review and whitespace checks establish document consistency
and preserve the runnable baseline. They do not establish new gameplay, human
balance, network or audio/voice acceptance. The project now maintains its brief
and design documents solely in Markdown.


## Offline survivor/content expansion

Run `godot --headless --path . --fixed-fps 60 --script res://tests/integration/content_expansion.gd`.
Add `-- --capture` and remove `--headless` for actual viewport captures (use
`--audio-driver Dummy` for silent graphical runs). The full runner now includes
this suite. It checks six role configurations in both mode flags, supply counts,
private baseline isolation, ignition boundaries and bonus nonduplication, then
selection/settings/Back/Start, number/keypad input, six-type capacity, dropped
pickup single-award recovery, rare consumables, nine-region nonoverlap/multiple
entrances, sprites and guardian sensing/destination limits. Existing navigation
suites cover the expanded region centres and spawn points. Replay expectations
now include the survivor confirmation and seven-type supply distribution.

See [content evidence and limits](content_update.md). Modifier/actor fixtures and
rendered tours do not pass the human M1-S balance gate or establish all-role
input-only escape rounds, online play, synchronized sounds or voice.


## Real ENet peer verification

The network tests launch separate OS processes using production Host/Join lobby
button callbacks and actual ENet RPCs. No local actor fixture substitutes for a
connected peer. Run from the repository root:

```sh
python3 tools/verify_network.py --mode all --players 2
python3 tools/verify_network.py --mode all --players 4
python3 tools/verify_network.py --mode all --players 2 --graphical
```

`--mode camp` or `--mode woods` restricts the case. Headless tests use UDP
27943/27945 (camp, two/four peers), 28043/28045 (woods), and graphical cases add
1000 to isolate concurrent runs. The normal game defaults to UDP 27840.
Each case runs host plus one/three guests; two-peer cases also attempt a late
join and verify rejection. Per-process JSON/assertion logs and indexed reports
are written under `artifacts/network`; the runner rejects missing results,
errors/warnings, nonzero exits or failed assertions and enforces a timeout.

Checks cover roster/readiness/rule changes, locked seed/role/private bonuses,
two-way movement, contested single-award pickup, rejected forged role/action/
nonfinite input, injury/revive/one-time kit consumption, down/drop/disconnect
objective recovery, flares and woods bolts/patches, remote ignition, boarding,
shared extraction, same-seed restart and host-loss cleanup. A deliberately
incomplete snapshot proves that partial state is not applied and a later
complete sequence recovers. Payload pieces stay at or below 1000 bytes, with
bounded assembly/decompression. The content suite separately verifies twenty
drop/recovery cycles do not grow the transient pickup list.

Host-only controlled placements, inventory/damage and paused AI isolate rules;
these are not human or input-only co-op horror rounds. Graphical cases operate
real windows with scripted inputs and capture connected lobby/host/client views.
The [preserved report](evidence/multiplayer/summary.json) records 24 process runs
and 685 passing network assertions, zero errors/warnings. The baseline full
runner passed 75 steps; final content passed 326 headless and 344 graphical checks.
The final four-window Camp test added 124 assertions, including roster layout captures.

Real two-machine LAN/Wi-Fi or cross-network Internet/VPN, human co-op/balance,
high-latency/jitter, other desktop platforms and exports remain unverified.
No microphone is opened and no voice acceptance is implied. Follow
[connection instructions](multiplayer_guide.md) for a separate-device test and
[audio/voice design](audio_multiplayer_design.md) for the next feature's gates.


## Current rescue and shared-light regressions

The latest [report](evidence/rescue_lighting/summary.json) preserves two/four
actual graphical ENet peers in both modes: **14 process runs / 480 assertions**,
all passing. Terrain-only pixel comparisons prove remote beams and flares light
the other screen. Down tests cover all gear dropping once away from the body,
repeat-hit/time persistence, mandatory medkits, no spawn-bonus refresh and van
rescue of an unrevived downed peer. The latest offline suite passed **75 steps**,
including **350 content assertions**. Earlier multiplayer reports above describe
their historical pre-amendment rules; the current player guide is authoritative.


## Active AI and alternating downs

The latest [network report](evidence/active_ai/summary.json) records **654 passing
assertions / 14 real graphical process runs**, two/four peers in both modes.
Stalker and roaming-cryptid movement continues during four alternating host/guest
down/revive cycles, with all enemies enabled and fixture wards/positions. Tests
check living-target preference, medkit pickup beside a body, private empty-E
feedback, client-visible enemy stride and absence of false defeat while someone
is standing. Authoritative all-down still ends defeat; repeated downs do not
accumulate a loss. Input-only solo escape/loss uses the new central patrol route.


## Navigation aids (overhaul F1)

Run `godot --headless --path . --fixed-fps 60 --disable-vsync --script res://tests/integration/navigation_aids.gd`.
Add `-- --capture`, remove `--headless` and use `--audio-driver Dummy` for
viewport captures. The full runner includes both forms. The suite checks
signpost reproducibility, spacing and open-trail placement for four seeds. It
proves every arrow leads one trail step closer to camp or its region, using
independently computed distance fields. It also covers skyline edge clamping,
bearing and range limits, HUD sign readout, the camp + woods boltcutters and
the crowbar, reachability, a crowbar-pried cache waking a listener 420 px away,
one-pair-per-survivor, M-key pins (cap of three, place names) and downed
rejection. `network_peer.gd` adds a guest pin accepted by the host and
replicated to every client (`lnac-net-4`). Evidence: [navigation](evidence/navigation/README.md).


## Night phases (overhaul F2)

Run `godot --headless --path . --fixed-fps 60 --disable-vsync --script res://tests/integration/night_phases.gd`
(add `-- --capture` without `--headless` for the Witching Hour HUD capture).
It checks the seeded reveal schedule and phase-tied events on three seeds, and
progress phase boundaries and clock text. It confirms three parts are sealed at
Dusk, that the pack names each part's radio phase, that a quiet team drifts into
Nightfall only after 12 minutes (which announces fuel and drops supplies), that
two installed parts stay in Nightfall while the third brings Deep Night, that
drift never reaches the Witching Hour, and that the fourth part does (revealing
the last part, with no dawn countdown). The stalker's hearing ×1.21 and speed
×1.08 increase on schedule. It also covers storm hearing masking at 80% range plus lightning,
blackout lamps and the generator restart, and the director: it steers one
distant roamer to a fuzzy area, never uses a creature within 400 px, honours
relief windows and ignores survivors in camp. Finally it checks there is no dawn deadline
after two more hours and that Witching Hour dread keeps rising. `network_peer.gd` adds a host-advanced
Nightfall replicated to clients with the fuel cache visible (`lnac-net-5`).
Legacy route tests reveal staged parts with `reveal_all()` and disable the
director. Evidence: [night phases](evidence/night_phases/README.md).

## Chase toolkit (overhaul F3a)

Run `godot --headless --path . --fixed-fps 60 --disable-vsync --script res://tests/integration/chase_toolkit.gd`
(add `-- --capture` without `--headless` for the flash capture). It covers:

- first-hit wound and grace, the HUD warning, wounded sprint speed, blood drops,
  and fresh blood pulling a patrolling hunter;
- medkit patch rules, second-hit down, and the downed crawl distance;
- the solo self-recovery hold, reset, noise and once-per-night limit;
- flash cone, cost, cooldown and immunity, and that stunned creatures can't move
  or attack;
- teammate help calls and cooldown, the bare-handed revive prompt and timing,
  and ping expiry.

`offline_slice.gd` now asserts wound-then-down and the solo last chance before
defeat. `network_peer.gd` checks that kitless revives are slower than kit time,
and that a guest flash stuns on the host and replicates (`lnac-net-6`).
Evidence: [chase toolkit](evidence/chase_toolkit/README.md).

## Hiding, doors and knock-overs (overhaul F3b)

Run `godot --headless --path . --fixed-fps 60 --disable-vsync --script res://tests/integration/chase_props.gd`
(add `-- --capture` without `--headless` for three captures). It covers:

- spot, door and knock-over counts, and that every spot is reachable on the
  native nav bake;
- hiding: snap-in, invisibility, hit immunity and no movement while hidden;
- breath drain, the gasp ejection a creature hears, and recovery;
- light restored on leaving, and a chasing witness dragging the survivor out;
- door slam blocking the path, a fixture break at 2.5 s, the smash window and the
  doorway guard;
- a **live AI** stalker routing to a noise behind a closed door, breaking in and
  reaching it;
- knock-over stun, lane block, expiry and one use.

`network_peer.gd` adds a guest hiding via interact and a host door slam, both
replicated, with the client door collision checked by raycast (`lnac-net-7`).
Evidence: [hiding/doors](evidence/chase_props/README.md).

## Road network (overhaul F4a)

Run `godot --headless --path . --fixed-fps 60 --disable-vsync --script res://tests/integration/road_network.gd`
(add `-- --capture` without `--headless` for the lit-road and field-map captures).
It covers:

- the same road layout on three seeds, with every clearing still connected;
- the ring loop size, and every spoke reaching the map edge;
- the ring passing through all three objective regions;
- every non-region road segment clear across three parallel lanes, and road
  tiles marked;
- native-navigation walking times from camp to every region, with the three
  required regions under 60 s;
- road lamps on camp power, going dark in a blackout and returning;
- the "LIT ROAD" location label.

The expedition bot (`woods_playthrough`) runs unmodified on the new map.
Evidence: [road network](evidence/road_network/README.md).

## Rotating regions and clues (overhaul F4b-1)

Run `godot --headless --path . --fixed-fps 60 --disable-vsync --script res://tests/integration/rotation_clues.gd`
(add `-- --capture` without `--headless` for the note and pack captures). It covers:

- 24 seeds: three caches in three distinct directions from the region pool,
  reproducible, with 4 ranger notes on walkable road cells outside regions and
  each nearer its region than camp is;
- all 8 pool regions used across seeds, and no rotation or notes in Quick Camp;
- corkboard fuel named, others direction-only, and the pack text;
- notes: reachable, prompt, region named for the team, not carried;
- entering a sealed region names it, and the skyline marker shows the part;
- after the radio reveal, standing in the region marks the cache.

`road_network.gd` also asserts that no woods wall edge lies on a nav chunk seam
(it fails with 75–83 such edges on the old seam layout) and that gameplay
targets sit outside the seam strips. The network night stage now checks that a
host-read note replicates to clients.

## Shortcut gates, fences and the new sounds (overhaul F4b-2)

Run `godot --headless --path . --fixed-fps 60 --disable-vsync --script res://tests/integration/barriers.gd`
(add `-- --capture` without `--headless` for the fence and gate captures). It covers:

- five seeds: at least 2 gates and 30 fences, every fence with a detour of at
  least 8 cells, and every clearing reachable from camp with all barriers
  closed;
- fences block walking and creatures but not sight; vaults are quiet at a walk
  and loud at a sprint, land on the far side, restore collision and play a thud;
- a gate is latched from the road side, opens from the region side for the
  team, and its nav route shrinks from about 1,436 to 44 px once open;
- open gates let survivors through, and gate state is in the snapshot.

`chase_props`, `night_phases` and `audio_polish` assert the new sounds (door
thud, wood_falling, the radio broadcast, a call per species, decoded gain
staging for all 23 cues). `network_peer.gd` checks that a host-opened gate and
its nav link replicate.


## Forest treeline cardinal views

`treeline.gd` finds four actual solid trail borders, captures normal-exposure
north/south/east/west views, and verifies blocked neighboring cells/creatures
and movement collision. Its graphical run toggles only the foliage overlay to
measure readable leaves, then checks bounded camera lookahead, HUD clearance and
camp recentering during actual walking. The standard runner includes headless
and optional graphical versions. Before/after images are engine captures after
settling the camera and view-local scenery cache, with no exposure boost.

Graphical sight tests isolate world pixels from HUD/skyline/weather overlays and
probe the neighboring trail floor away from overhanging trunks. Hidden floor
must stay black even at full ambient, while disabling the mask exposes it.
Shadow tests separately toggle native border occluders and require real light
leakage in that positive control. Fixture startup waits for the ForestLevel to
finish loading instead of assuming it exists after a fixed number of frames.


## F5a Radio Rescue

Run the focused objective suite (also included in `tools/verify.py`):

```sh
godot --headless --path . --fixed-fps 60 --disable-vsync --script res://tests/integration/radio_rescue.gd
godot --path . --audio-driver Dummy --fixed-fps 60 --disable-vsync --script res://tests/integration/radio_rescue.gd -- --capture
python3 tools/verify_network.py --mode woods --players 2 --graphical
python3 tools/verify_network.py --mode woods --players 4
```

The solo fixture covers seeded, unique fuse generation; native paths to all
seven actions; pickup/drop/recovery; circuit idempotence; no clock gate once powered; real
held input; release/operator changes; exact flare spend; explicit ready start;
pause; state restoration; and inside/outside/downed extraction. Captures include
normal-night structures/signals, objective UI and a generated eleven-region atlas.
The network fixture drives the radio chain from a real remote peer in the second
round, checks all client signal lights and shared results, and recovers a downed
host. Placements and time acceleration isolate mechanics, not human balance.
Cross-machine Internet, listening tests and human pacing remain unverified;
the user deferred human playtests for F5a.


## F5b Boat / Ranger Gate and SpriteCook

```sh
godot --headless --path . --fixed-fps 60 --disable-vsync --script res://tests/integration/field_escapes.gd
godot --path . --audio-driver Dummy --fixed-fps 60 --disable-vsync --script res://tests/integration/field_escapes.gd -- --capture
python3 tools/verify_network.py --mode woods --players 2 --graphical
python3 tools/verify_network.py --mode woods --players 4
```

The focused fixture checks four reproducible recipes, unique separate inventory,
native routes to parts/dock/bridge, motor speed and drop priority, held assistance,
no clock gates (a ready escape brings the Witching Hour), two-second splash tells, wound/dodge/flare counterplay, shared-state
restoration, physical arm opening, alarm sensing without teleport, full departure
windows, downed recovery and fresh-round cleanup. The network harness drives all
four escapes across separate rounds, with a real remote Boat/Gate operator,
shared assistance/tells/collision and route-specific results.

Art reproduction: `tools/slice_escape_props.gd`, source/derivative IDs and hashes
in `spritecook-assets.json`. One 16-piece batch cost 12 credits, with no paid
cleanup/animation. Capture fixtures generate a current fourteen-region atlas.
Human pacing and cross-machine acceptance remain pending; see
[F5b execution evidence](evidence/boat_gate/README.md).

## Proximity voice

```sh
python3 tools/verify_voice.py
```

Runs headless with the Dummy audio driver and never opens a microphone.
`voice_chat.gd` checks that the TwoVoIP extension loads, B is bound to push-to-
talk, a real Opus encoder's packets (20 ms, 48 kHz mono) decode through
`VoiceChat.accept_packet`, late packets drop and a single loss is rebuilt with
FEC, the routing table (nearby/out of range/downed/boarded/ghosts), packet size
and per-peer rate limits, and that voice settings and the next-launch microphone
override persist and release. `voice_peer.gd` then starts a host and a client
process: both stream a synthetic tone in the lobby and must decode each other,
then ready up into a Quick Camp round where the host checks positional playback
from the teammate's survivor, silence beyond 420 px, and ghost isolation.
Logs and `summary.json` go to `artifacts/voice/`. A real microphone needs a
person to approve the macOS permission dialog once, so it is not automated.

## Roles 2.0 abilities (overhaul F6a)

`tests/integration/roles_abilities.gd` (in `verify.py`) checks every role has an
ability; Second Wind refills stamina, adds 10% sprint, is spent until the next
phase and shows on the HUD; Jury-Rig barricades a door that a pushing stalker
cannot break until it expires, restarts dead power, and has two charges; Mark
tags a creature in sight, has a 30s cooldown, fades after 6s and never tags an
unseen creature; Patch heals a teammate and self with two charges; Hold Breath
silences sprint noise and has a 45s cooldown; Unpack drops four supplies once;
H hands one flare only to an adjacent teammate; the Jock hauls the motor at full
walk, the Quiet Kid leaves no blood, two survivors restart the generator
quietly while one is loud; awards appear on the results screen.
`network_peer.gd` adds a guest Jury-Rig accepted by the host and replicated.

## Signal Fire, rumoured escapes and the van finale (overhaul F5c)

`tests/integration/signal_fire.gd` (in `verify.py`) checks that across 40 seeds
each night offers the van plus exactly one secondary, all four secondaries
rotate, only tonight's escape parts (and the shared fuse for radio/gate) spawn,
Signal Fire parts sit in three different regions, and the choice is
reproducible; Quick Camp stays van-only. With `--all-escapes` it walks the full
Signal Fire chain (reachable pyre and parts, no belt slots, ready pyre brings
the Witching Hour, lighting draws the stalker, 45s hold-out, escape from the
ring), the 20s expedition van departure whose start and revs call creatures,
and then, on a real Signal Fire seed, that absent escapes have no prompts, the
Dusk message names the rumour and T shows the pyre plan. `radio_rescue.gd`,
`field_escapes.gd` and all network peers run with `--all-escapes`.

## Headline killers, escalation and modifiers (overhaul F7)

`tests/integration/killers_modifiers.gd` (in `verify.py`) checks across 60 seeds
that both headline killers rotate, all six modifiers appear (0–2 distinct per
night), Fog Bank forces fog, Generous Woods adds supplies and Blood Moon adds
hounds/jackals without changing the creature count. With the Groundskeeper it
checks snares only on walked trails with spacing, the 4s hold and rattle that
calls him, no movement while snared, a teammate's instant release, quiet disarm
and the timeout; Dusk inner-ring chase limit vs Nightfall; Deep Night tier with
longer search, one sabotage of an unguarded van (part dropped and pinned), one
Witching Hour power cut, and 1.5× door breaking. Modifier effects: Dead
Batteries (40 charge), Silent Night hearing, Blood Moon speed, Lone Wolf
spawns. `woods_replay.gd` runs with `--no-modifiers` because it checks the
baseline loot recipe; `network_peer.gd` checks a host snare reaches clients.

## Score, profile and journal (overhaul F8)

`tests/integration/meta_progress.gd` (in `verify.py`) confirms tests use
`user://profile_test.cfg` (never the real profile), grade boundaries, the daily
date seed, score arithmetic, badge awards (once only), best-per-seed retention,
three-route Route Master, sighting/journal text and persistence. In a real round
it checks a first sighting unlocks a journal entry, notes count, and the results
screen shows score, grade, new badges and the best score; on the menu, Daily
Night uses today's seed and the Camp Journal opens and closes.

## Story events, build-ups and the audio revamp

`tests/integration/night_events.gd` (in `verify.py`) checks the Hunt Begins
(remembers only inner-ring loud noises, the horn plays, roamers go to the last
noise), the Stalker's Gift (placed and pinned, gives supplies, its bell calls
the killer, pin cleared), the Lost Camper (pinned, follows the first survivor,
panics when chased, reaches camp for a medkit, +250 score), director build-ups
(flashlight flicker and a distant call) and the audio revamp (wider call and
step ranges, the killer screams in a chase, the distant chorus, a call heard at
450 px). `night_phases.gd` checks the schedule now carries two of the three
story events in sorted phases; `woods_visibility.gd` checks the new call range.
