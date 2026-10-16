# Development log

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
