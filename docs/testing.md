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
