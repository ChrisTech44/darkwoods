# Development log

## 2026-10-18 — Stalker-only nights, nine new creatures, mower Groundskeeper, region identity

User asked to finish the remaining review items, make the Groundskeeper "very,
very different" with an awesome mechanic, then changed direction: the Stalker
stays the only headline killer, the Groundskeeper becomes a woods creature, add
more creatures with unique fun/penalizing/annoying verbs and improve regions,
using SpriteCook down to 400 then 300 credits.

- **Stalker every night.** `RoundPlan.HEADLINES = ["stalker"]` (the old RNG roll
  is kept so modifier picks per seed don't shift); bear traps always; trap
  prompts renamed; the Groundskeeper killer sheet/cue branches removed. Badge
  "Snare Dancer" (id kept for old profiles) is now **Mower Mechanic**: pull the
  Groundskeeper's spark plug and escape (`level.feats`, synced).
- **Groundskeeper creature** (`brains/groundskeeper.gd`): ride-on mower with
  momentum steering (1.9 rad/s turn, brakes for sharp turns), headlight-cone
  sight (270 px, plus 46 px around) with a real PointLight2D headlight, runs
  survivors over (35 + launch); loses you behind trees/cabins/hiding spots,
  parks and walks with a rake that drags people out of nearby hiding spots,
  then returns; hold E 3 s at the parked mower to pull the spark plug (90 s on
  foot, loud). Engine is a positional loop on every peer. New generic hooks:
  `level.holding(actor)` and `creature_prompt()` so creatures can offer E actions.
- **Eight more creatures**, each with a verb nothing else has: Cuckoo (rewind
  8 s after three calls in sight), Banshee (inhale ring then deafness: local
  low-pass and ducking on Effects/Ambience/Music), Slug (slime skid physics;
  salt ward shrivels it), Surveyor (LOST: map scribble, skyline/signposts/
  location/place titles hidden; teammate 3 s or a ranger note cures),
  Hitchhiker (rides your back: slow, no sprint, lights off; TAG a teammate),
  Tollkeeper (pay a supply or be shoved back), Echo (fake stalker whistles,
  played per peer; light bursts it), Fortune Teller (forced tarot card, 3 boons /
  4 banes, on-screen card). Roamers 18 → 21 and 30 creatures total, keeping the
  17 October playtest cap: 22 roaming kinds (duplicates and the roaming Witch
  removed; she stays in the bog), so one kind rests each night, rotating with
  the seed. Blood Moon now also turns the Echo, Hitchhiker and Cuckoo into
  werewolves, so it still converts five. Names, tips, threat rows, calls,
  player effects (`slimed`, `piggyback`, `lost`, `deaf`, `dark`, `rewound`,
  `card`) and the field guide updated.
- **Regions:** each landmark's searchable centrepiece is its own object (sluice
  valve, cider press, candle lectern, telescope, track switch, ore cart) on a
  halo in the region's colour, replacing the shared altar; nine regions get a
  gateway object (village sign, bog boardwalk, graveyard gate, flood gauge,
  orchard arch, lychgate, armillary pillar, rail crossing, mine sign) placed
  beside the trail at the crossing nearest camp.
- **SpriteCook:** 60 credits (476 → 416, floor 300): relic + mower sheet,
  creature sheet F (first try came back 64×64 because width/height act as the
  whole canvas; re-run as an edit at 512), sheet G, entrance sheet. All asset ids
  and sha12 in `spritecook-assets.json`; slicing in `tools/slice_landmark_props.gd`
  and `tools/import_spritecook_creatures.gd -- --only <sheet>`.
- Tests: new `tests/integration/new_creatures.gd` (33 checks, added to
  verify.py); `killers_modifiers` updated for stalker-only nights; the monster
  roster check now requires the Groundskeeper to spawn.

Verification: full `python3 tools/verify.py`: 197/197 steps passed with no
warnings (exit 0). Earlier runs on this increment caught and led to fixes for:
the woods_replay species count (the Stalker is now the only journal entry that
never spawns), Blood Moon converting too few creatures, the Mower Mechanic badge
test, and the 30-creature playtest cap. Graphical captures:
[creature evidence](evidence/creatures/README.md) (staging and limits listed
there). Not established: mower chase feel and speed tuning in live play,
balance of the tarot table and Tollkeeper placement, co-op behaviour of TAG,
LOST guidance and the Echo's client whistle, and listening checks.

## 2026-10-18 — Building names, place titles, clearer names, skyline layout

User asked to fix building-name readability and name duplication/clarity next
(the camp-song leak is deferred).

- **Building names:** the roof (which fades as you approach) and the interior
  top wall no longer paint the name. Each building has a post-mounted name
  plaque beside its door, below the eave and clear of the porch awning
  (`CampBuilding.plaque_rect`). Because the plaque is outside the flashlight
  cone on a normal approach, the skyline layer also shows the name anchored on
  the plaque when you are within 130 px **and** have a clear line to the door
  threshold (walls block it; never from inside). The location line reads
  `OUTSIDE <BUILDING>` within 56 px of a door.
- **Place titles:** entering a building, a woods region or camp shows a short
  lower-centre title with a subtitle (e.g. `MAINTENANCE / CAMP BUILDING`,
  `RANGER ROAD AND BRIDGE / NORTH WOODS`). It waits 0.5 s so a doorstep does not
  flicker, does not repeat the same place within 10 s, skips the opening place
  (the Dusk title covers it), gives way to phase titles and hides under the
  notebook. `THE WOODS` is shown only on leaving camp.
- **Names:** short names are now words from each full name: OBSERVATORY (was
  DOME), GRAVEYARD (GRAVES), RAIL YARD (RAILS), SUBSTATION (POWER), RADIO RELAY,
  LOGGING CAMP, LAKESHORE (BOAT), RANGER GATE (GATE). The camp building is
  `CAMP BOATHOUSE`, distinct from the woods' Lakeshore Boathouse. Signpost
  boards now size to their measured text instead of a fixed 34 px.
- **Skyline:** one layout pass (`Skyline.layout`) for help calls, tracked
  objectives, door names, pins and landmarks: priority order, icons within
  14 px merge into `+N`, labels try below/above/further below and never enter
  the top HUD band or another label or icon; plain landmarks with no room keep
  only their icon; labels get a dark backing. Hidden while the notebook is open.
- New `tests/integration/world_labels.gd` (plaques clear of roof/awning, distinct
  boathouse names, short names derived from full names, place title and doorstep
  repeat, location line, crowded skyline never overlaps and stays out of the top
  HUD, help wins and merges). Added to `tools/verify.py`.

- **Camp-song leak fixed:** the synthesized whistle was the only round sound
  that played without an audio device, and the shutdown drain only runs with
  one, so a whistle mid-play at exit leaked its `AudioStreamWAV` playback
  (intermittent `2 ObjectDB instances were leaked`). It now plays only with
  audio output (like every other round sound) and stops with `round_audio`.
  `offline_playthrough` ×3, `woods_playthrough` and `monster_revamp` then ran
  with no warning.
- The skyline keeps optional labels out of the place-title box.

Verification: full `tools/verify.py` before the leak fix: 183/183 passed (the
only warnings were that leak). After the leak/place-box changes: import and
startup clean; `world_labels` 11, `navigation_aids` 45, `offline_playthrough`
×3, `woods_playthrough` 227, `monster_revamp` 140, all passing, no warnings.
Captures: [label evidence](evidence/labels/README.md). `git diff --check` clean.

Still open from the review: region landmark identity (repeated shrine props).

## 2026-10-18 — Sound pack, notebook/map overhaul, moon dial, radio transcript

User supplied 17 MP3s and asked to fix the marked defects, integrate the audio
(with trimming and loudness attention), deliver the planned help menu/map, add a
moon phase indicator (red under Blood Moon) and show what the ranger radio says.

**Audio.** Each file was cut (silent heads/tails, over-long takes: whine 11.6→3.5 s,
gurgle 7.8→3.0 s, camera charge 4.7→1.1 s to fit the 1 s wind-up, sneeze tail
0.8 s, grunt lead 0.57 s, lullaby gap 1.3 s), taken as **left channel mono**
(summing cancelled some stereo files; the grunt measured −90 dB mean after a
mono sum), and levelled to about −20 dB mean with peaks ≤ −1.4 dBFS via ffmpeg
`volumedetect` then `volume`, MP3 128 kbps. `giggle_use_first_half_only.mp3` became
`giggle.mp3` (first half). Runtime `gain_db` sets the mix by role. Originals were
kept out of the repository. 67 cues now; table and edits in the
[audio README](../assets/audio/README.md#18-october-2026-sound-pack).

- Fixed: air horn plays (was silent); bear trap plays **one** snap (removed the
  direct `metal_clang` in `Snares.advance`; the replicated snare edge owns it).
- Creatures: Buster bark/happy whine, Paparazzo charge→shutter, Conductor train,
  Bear Hug squeaks, Bog Hands gurgle, Imps giggle, Lullaby Saint song as a
  positional loop within 300 px (drowsiness radius 170 px; old bells cue removed),
  frog-curse croak loop. Survivor grunt on hit, gasp when held/downed, sneeze per
  Puffball `achoo`, scissors snip, helicopter rotor over the landing zone during the
  radio-rescue hold-out.
- New `CampSoundscape.broadcast`: host-only events (all `CreatureBrain.cue`, item
  sounds, stalker grab/frenzy, lock rattle) are played on the host and logged
  with ids in the snapshot; clients replay each id once. Survivor voice/loop
  sounds are inferred from replicated state on each peer.

**Interface.** Tab notebook (`scripts/ui/notebook.gd`) replaces the overlapping
pack/chart: MAP, ESCAPE PLAN, FIELD GUIDE, LOG views in one bounded panel
(y 44–148) clear of belt, location and prompt. Tab pages forward and closes after
LOG, Shift+Tab back, Esc closes before pausing, Z zooms/turns topic, T opens the
plan or cycles routes, mouse clicks tabs/routes/topics. Online the header says the
world keeps moving; offline Tab still does not pause (unchanged policy).

- Map rewritten (`camp_chart.gd`): one uniform scale with letterboxing (G06),
  local woods view or whole woods, objective markers from **live** pickups for the
  selected route (installed/carried parts disappear, dropped parts show where they
  lie, G03), teammates and downed teammates (G04), escape destination diamond,
  pins, help pings, edge arrows for off-map markers, region names last and only
  when they fit. Map works on every route (G05). Same discovery rules as before.
- Field guide content (`scripts/ui/field_guide.gd`) shared by the title screen
  and notebook; keys read from the InputMap; obsolete rules removed (G07).
- Moon dial (`moon_dial.gd`): new until Nightfall, waxes as the cloud gap runs
  down, full and glowing with a run-down ring while out, red under Blood Moon.
  `moon_clock`/`moon_span` now replicate. Replaces the old moon icon.
- Phase titles and ranger radio transcript (`night_broadcast.gd`): ~2.75 s title
  per phase (Dusk once), and a CH 9 strip where the radio's words crawl across
  the screen after the static; kept in the notebook log. `NightClock.radio_text`
  replicates. Titles shrink while held/downed.
- World fixes: duplicate Logging/Boathouse/Ranger titles removed (one owner,
  with outline); "MOTOR / HEAVY CARRY" only when the boat route is on and the
  motor still lies there; "E / RARE TOOL" removed once searched; faded killer's
  shadow fades; pickup piles label once ("FLARE ×3", "SUPPLIES ×N").
- README header image (deleted werewolf screenshot) replaced by a stalker
  calling-card frame from the existing clip.

Not done from the reviews: building-name/roof readability, shared skyline
label compositor, region-entry titles, landmark silhouettes, the second sound
batch (snore, tin rattle, UI clicks, flare ignition, thread snap) and a separate
UI-resolution canvas. Structured objective model (plan slice 2) is partial: the
map derives state from live pickups/inventories; plan text is still the
existing per-route text.

Verification: import and five-frame startup exit 0 with no engine errors or
warnings. `python3 tools/verify.py` (headless, 179 steps incl. every parse
check and all integration suites, plus new `sound_feedback`) all passed; the
only warning was `woods_playthrough`: 2 leaked ObjectDB instances at exit, which
`--verbose` identifies as the synthesized camp-song `AudioStreamWAV` and its
playback. The same warning reproduces on the previous commit (24480a8, clean
worktree), and appears intermittently in `offline_playthrough` (1 of 3 runs), so
it is pre-existing and timing-dependent, not fixed here. After a later Shift+Tab
fix (caught by the new test: it read global key state instead of the event's
modifier), `notebook` (21 checks), `offline_playthrough` (132) and `menu_smoke`
(37) passed. Other suites were not rerun after that one-line input change.
`sound_feedback`: 27 checks. `audio_polish`: 117. `monster_revamp`: 140.
Graphical captures (`tools/capture_notebook.gd` with `--all-escapes` and
`--blood-moon`, `tools/capture_world_review.gd`) exited 0; images were opened and
inspected; staging is labelled in [notebook evidence](evidence/notebook/README.md).
`python3 tools/verify.py --graphical` was not run. No co-op session, window-size
matrix, listening/mix check or human comprehension test was run. `git diff
--check` passed.

## 2026-10-18 — World graphics critique, phase titles and sound recording gaps

User requested a broader graphics/label review, discussion of dramatic phase
text and a repository sound wishlist/missing-feedback analysis as a game critic.
This increment adds review documents and diagnostic tools, not gameplay fixes.

- [World graphics review](world_graphics_review.md): 48 captured/inspected views
  across ten camp buildings, fourteen region types, signposts, crowded bearings,
  phase transition and bright inspection cases. Twenty selected images retained.
  Confirmed duplicate region titles in Logging/Boathouse/Ranger: the helper and
  generic renderer draw the same name four pixels apart on both axes. Documented
  dark/fading roof names, partial flashlight-lit ground names, skyline collisions,
  crowded pickup labels and painted instructions independent of availability.
- Critique distinguishes defects from artistic judgments: repeated shrine
  compositions weaken region identity; substation/relay silhouettes read well.
  Proposed canonical place names, shared label layout/visibility priorities,
  region-entry titles and a brief dramatic phase overlay with accurate Deep Night
  camp-safety warning, responsive controls and peer deduplication requirements.
- [Sound gap review](sound_gap_review.md): reconciled all 13 existing wishlist
  entries; prioritized missing condition/action/noisemaker/light/objective cues,
  creature signatures and later extraction/place/UI feedback. Supplied a first
  batch of twelve sound sets and source/runtime format guidance. Current loader
  expects MP3 streams; WAV source requires runtime conversion or loader work.
- Static registry audit: 50 cues, no missing referenced files or unregistered
  literal playback calls. Headless diagnostic: successful horn accepted no cues;
  one bear trap requested `metal_clang` twice and `chain_rattle` once. An AI noise
  stimulus is not speaker playback. Special host-brain cues still need remote
  event/listening verification. These are findings, not repaired audio triggers.
- Updated audio README's obsolete assignments/ranges/voice statements and added
  a current-status/history distinction to the audio design. Linked reviews from
  README, prior plan and maintained agent documents.

Verification: required import and five-frame startup exited 0 without engine
errors/warnings. Both new tools passed Godot `--check-only`. Final graphical
fixture exited 0 with 48 successful PNG writes and no errors/warnings. A first
capture waited for a window redraw and was terminated; the tool now explicitly
forces rendering. An intermediate completed run reported two ObjectDB cleanup
leaks; final fixture closes metrics output and drains phase radio timers before
shutdown, with no final warning. No runtime leak/performance claim follows from
that diagnostic staging issue. Sound diagnostic exited 0; registry audit and
changed-document local links passed; `git diff --check` passed.

[Evidence, commands, selected images and logs](evidence/world_review/README.md).
Microphones remained unused. No full gameplay regression suite (no gameplay
source changes), exports, live four-peer graphics, actual listening/mix evaluation
or normal-speed motion/human comprehension test ran. The graphics pass remains
bounded to the documented seed, placements and source inspection; future QA
matrix and implementation acceptance are in the reviews.

## 2026-10-18 — Graphics audit, notebook plan and maintained agent baseline

User requested graphics bug review, a readable map/Tab-help/hint overhaul plan,
and updates to the previously outdated agent documents. This increment audits
and plans; it changes no gameplay/UI runtime source.

- Added [graphics/readability audit and delivery plan](graphics_readability_plan.md):
  eight confirmed defects/discrepancies with source causes, separate code-backed
  concerns, proposed Map/Escape Plan/Field Guide views, objective state model,
  next-action/event presentation and four implementation slices with acceptance.
- Reproduced map-over-objective text, notes/frame intrusion into belt space,
  persistent original battery map marker after pickup consume/van delivery,
  secondary-plan map hiding, tiny/dense help and obsolete “Solo build”/fixed-cache
  guide. Code also confirms missing teammate map markers and distorted woods
  map scale. No claim that these have been fixed.
- Added reusable `tools/capture_readability_audit.gd`; preserved ten actual
  normal-lighting graphical captures in [evidence](evidence/readability_audit/README.md).
  All routes are forced for inspection, enemies frozen, phase clock stopped;
  staged notice text is labeled. This is not a normal input playthrough.
- Replaced accumulated obsolete brief amendments with version 2.0: current
  routes/rotation, progress/time phases, shared killer behavior, implemented
  audio/network/voice versus remaining acceptance. Updated `AGENTS.md` to direct
  future interface work to the plan and verify claims against code/evidence.
  Older rules/history remain in this log and existing design documents.
- Added README link to the audit/plan; existing player-facing rules remain pending
  correction with the implementation slices. Real teammate map guidance is a
  documented current discrepancy.

Verification on macOS Apple M2 / Godot 4.7.2:

| Check | Result |
| --- | --- |
| Required headless import | Exit 0, no engine errors/warnings in final run. |
| Required headless five-frame startup | Exit 0, `menu_ready`, no engine errors/warnings. |
| New capture script `--check-only` | Exit 0, no errors/warnings. |
| Final graphical capture | Exit 0, all ten PNG writes `OK`; images visually inspected. |
| Local Markdown links | No missing targets in brief, agent rules, plan or evidence index; new README/log links checked. |
| `git diff --check` | Passed. |

Initial sandboxed import/startup printed macOS service/editor-settings/user-log
errors despite exit 0 and were not counted as passes. The first graphical run
captured nine screens; a second sandboxed launch stalled with window-service
errors and was terminated. Final import/startup and the completed ten-screen
capture ran outside the sandbox. Evidence retains final import/startup logs.
No full regression suite, exports, live four-peer screenshot session, real
microphone, or human comprehension/playtest acceptance was run. Normal-lighting
UI screenshots do not clear every terrain/sprite/animation case; those checks
are explicit future work in the plan.

## 2026-10-17 — README clips show the new monsters

All clips were re-recorded in real time (the old ones ran at half speed: two
physics steps per 15 fps frame at 60 Hz; now four). New clips: the stalker
shadowing a survivor and scrawling "I SEE YOU" behind them, the stalker grab,
the Mimic, the Toadstool Imps, the Night Owl, the Witch's frog curse,
Bigfoot's throw, the werewolf under the moon, Bear Hug and the face moth.
Storm, door and van were kept; the outdated chase, flash, hide, snare and
signal-fire clips and six old creature screenshots were removed.

Changes found while staging the clips:
- The stalker now writes calling cards himself: only when he's within reach
  behind his favourite, at his own spot, not 110 px behind them wherever he
  was.
- Cards fade in only under your flashlight (or within 60 px).
- The owl draws above the sight mask and grips the survivor while carrying.
- A flash that swats a moth no longer also says "nothing caught in the beam".
- The Mimic closes the last few pixels when navigation stops short.
- Witch curses and the stalker's next card can be forced (for clips).

**Verification:** `monster_revamp.gd` 140/140 after the changes. Every clip
was checked on a contact sheet. The full `verify.py` was not rerun for this
increment (usage limit).

## 2026-10-17 — The stalker's grip: you can't just mash out every time

The user asked what stopped a player freeing themselves every time. Answer:
nothing (14 presses, no penalty, while the walk to the hook takes about 20 s).
Changes, agreed with the user:
- **Struggle drains** while you aren't pressing (`CampPlayer.struggle_decay`):
  0.1/s for creature holds, 0.12/s in the stalker's grip. At about 6 presses/s a
  first stalker grab takes about 4 s, a second about 14 s, and a third needs
  very fast hands.
- **Each grab is harder** (`CampKiller.hold`): 8 more presses per previous grab
  by the same kind of creature tonight (the stalker: 14, 22, 30…).
- **He shakes you:** every 3 s while carrying he knocks back 25% of your
  progress; the view jolts (`jolted`, camera shake in `EffectsOverlay`).
- **Tearing free costs you:** 1 s on the ground (tripped) and you drop your held
  stack. Teammates' flashes, flares and the air horn still free you instantly
  with no cost.
- Fixed on the way: a recovery pause could freeze the stalker while he was
  carrying someone (his carry and shake stopped); holders now skip the pause,
  as cryptids already did.

**Verification:** `monster_revamp.gd` 140/140, with new grip checks:
- escalating presses;
- drain while idle;
- the jolt knocking progress back;
- tearing free tripping you and dropping what you held;
- a teammate's flash freeing you cleanly.

Also passing:
- woods_playthrough 227, chase_toolkit 29, offline_slice 65, design_feedback 52,
  chase_props 46, roles_abilities 33, night_events 31 and killers_modifiers 32,
  all 0 failures;
- two-player woods network round: all peers pass;
- `verify.py`: all 169 steps passed.

## 2026-10-17 — Monster revamp: one verb per creature, and the stalker at the centre

User request: revamp the monsters and add fun ones, not all lethal (stealing,
carrying players away, raising voice pitch); every monster drastically different,
tied to items (garlic for vampires…); R.E.P.O.-style novelty, punishment and fun;
and the stalker at the centre with his own characteristics. Design:
[monster_revamp.md](monster_revamp.md).

**Framework:**
- `CreatureBrain` (`scripts/ai/brains/<species>.gd`) gives each species its
  own verb; `cryptid.gd` is now a thin shared body. Brains run on the host;
  `brain_state` syncs drawing state to clients.
- Player effects (`CampPlayer.effects`/`effect_data`, synced):
  - frog, backwards, float, helium, sneezy, drowsy, asleep, hypnotized,
    whiteout, face moth;
  - tethered, marked, tripped, garlic, bug spray, coffee, glowing.
- Holds: `grab`, `wriggle` (mash E; a teammate's E counts double) and
  `release`; any stun makes the holder let go. Knockback (`shove`) stops at walls.
- `EffectsOverlay` draws what effects feel like: white-out, the moth over your
  face, drowsy and sleep, hypnosis, "HELD BY … · MASH E" with a bar, badges and
  the moon icon.
- Voice: helium and frog pitch buses. The Mimic's replay uses a 4 s in-memory
  ring of received (and own) packets, never saved.

**21 creatures**, each with a tell and a counter; ids keep their art:
- Hunters:
  - The Vampire: hypnotic pull, a draining latch; garlic.
  - The Werewolf: a hiker until the moon (NightClock moon cycle), then pounces
    and doors burst; wolfsbane.
  - The Scarecrow: moves only when unwatched; flash-proof.
  - The Ram: a charge that bowls everyone in its path.
  - Bear Hug: a relentless squeezing hug.
  - The Bog Hands: mud puddles that drag you under.
  - The Mimic: wears a teammate's look, name and voice.
- Pranksters:
  - Bigfoot: shy; throws you, or flees and drops scoring fur.
  - The Witch: frog, backwards, swap and float curses; the salt ward reflects them.
  - The Lantern Moth: lands on your face.
  - The Puffball: helium voice and sneezes.
  - Buster: barks for the stalker and drags the downed; rations befriend him.
  - Trash Jackals: steal for their den (a Rail Yard pair).
  - The Peeper: a staring lock.
  - The Paparazzo: a flash that sends your photo to the stalker.
  - The Conductor: no ticket means the Rail Yard; a ticket means a ride home.
  - The Snuffer: a darkness bubble.
  - The Seamstress: stitches survivors together.
  - The Lullaby Saint: sleep.
  - The Night Owl: carries lone survivors off.
  - The Toadstool Imps: trip you and hide your stuff.
- **The stalker** (`StalkerTraits`):
  - the whistled camp song (`CampSong`);
  - shadowing a favourite, and melting away in a beam;
  - the grab-and-carry to his hook (pinned), broken by mashing E, a flash, a
    flare or the air horn;
  - spot memory, bear traps (`Snares` generalised), calling cards, and rage to
    a 20 s frenzy.
- **Items:** garlic, wolfsbane, bug spray, scissors, train ticket, air horn,
  coffee and Bigfoot fur. Rations double as bait, the salt ward reflects
  curses, and glow moss also makes you glow.
- **Roster:** 27 creatures, a curated 18-roamer mix plus guardians, Buster
  unique. Blood Moon turns pranksters into werewolves and brings the moon out
  more often.
- **Art:** SpriteCook creatures E (owl, bog hands, imps, teddy) and a
  monster-items sheet (24 credits, 476 left). The importers regenerate every
  earlier sheet byte for byte.

**Fixed while testing:**
- The expedition bot was trapped by the vampire's pull (stronger than a walk,
  and unbroken by a flare). The pull is now weaker than a sprint, a gaze lasts
  at most 4 s with a 6 s rest, and a flare breaks it.
- `n` presses of `1/n` summed to 0.9999 and never broke a hold; the threshold
  is now 0.999.
- The post-hit pause now applies to brains that take the frame.
- Camp items placed 16 px from existing pickups stole the E press (the air
  horn from the cutters, scissors from the crowbar), and three landed inside
  walls. Camp creature items now sit on the porch beside a named building's
  door (the first spot clear of obstacles), and a check confirms every item
  is reachable and at least 30 px from other pickups.
- New woods items now skip region interiors (one landed out of reach).
- The Mimic and Bog Hands only enter the journal once revealed.
- A typed `CampCryptid` reference in `landmark_hazard.gd` pulled the new
  creature class cycle into its parse-only check, which then leaked two static
  scripts at exit; it is typed `Node2D` now.
- `network_peer`'s roster count was still 49 after the 26-creature change
  (the network suite hadn't been run then). It now reads `RoundPlan`.

**Verification (macOS):**
- `monster_revamp.gd` 135/135, including reachability for every creature item.
- `woods_playthrough` 227/0: the bot escapes with every creature live, and no
  script errors.
- forest_hunt 87, content_expansion 473 (with portraits), woods_replay 485,
  killers_modifiers 32, design_feedback 52, field_escapes 58, surround_world 102,
  night_events 31, night_phases 43, chase_toolkit 29, chase_props 46,
  offline_slice 65, audio_polish 100, roles_abilities 33, signal_fire 31; all 0
  failures.
- `verify_network.py` camp and woods, two players: all peers pass.
- `verify_voice.py` 24 + 8 + 13.
- Every creature, effect and overlay was checked in captured frames, and all
  21 portraits were retaken for the README.
- `verify.py`: the final full run passed its first 162 steps and stopped at
  `meta_progress`, whose journal check still quoted the old werewolf tip (it
  now reads the tip table). That suite and every remaining step were then run
  individually on the same code (meta_progress 27, night_events 31,
  roles_abilities 33, radio_rescue 34, field_escapes 58, design_feedback 52,
  monster_revamp 135): all 0 failures.

## 2026-10-17 — Playtest feedback: health, fewer creatures, a camp refuge, water, gates, voice

The game was played with friends; their findings and the changes made:
- **Too oppressive, little room to explore:**
  - creatures cut from 48 to 26 (a vampire and a witch in their regions, six
    guardians, and 18 roamers);
  - roamers are placed by seeded best-candidate sampling across the whole
    forest: each pick is the farthest of 12 random clearings from everything
    placed. None starts within 1,100 px of camp; no more clusters on the
    camp approaches.
  - **Camp is a refuge until Deep Night:** `CampKiller.camp_closed` (set at
    expedition start, lifted at Deep Night or when the van engine roars)
    blinds creatures to survivors in camp and deafens them to camp noise. It
    also pushes their routes out of camp and refuses steps or charges into
    it. The stalker spends the first half prowling a seeded woods clearing
    beyond camp, then tours camp. Lanterns at the four trail mouths burn
    while camp is safe.
  - the director waits until Nightfall and steers creatures less often
    (110 to 40 s apart, was 75 to 25).
- **Health bar, health packs, cooldowns:**
  - survivors have 100 health (HUD bar, red edge flash on a hit); 50 or less
    is wounded; 0 downs;
  - each creature has [damage, cooldown] in `CampKiller.THREATS`: easy to
    evade means hard-hitting with a long recovery (Bigfoot 60/5 s, Stoneback
    Ram 55/5 s, stalker 50/4 s); quick creatures hit lightly but are easy to
    counter (moths, wraith and jackal 15 with a 1–1.2 s cooldown);
  - after a landed hit the attacker stands still for half its cooldown (max
    2 s), and every hit grants 1.5 s of grace, so no back-to-back hits from
    one or several creatures;
  - a medkit heals 50, rations heal 10 and the medic's Patch heals fully;
    revived survivors have 35 health; health is in the network snapshot.
- **The Groundskeeper moonwalked:** his importer had swapped the left and
  right poses. Fixed in `tools/import_spritecook_groundskeeper.gd` and the
  sheet rebuilt. All 25 character sheets were checked side by side; the
  others were correct.
- **Name not kept for another night:** the lobby saves name, address and port
  to `user://lobby.cfg` and shows the session's name on return.
- **Gates looked wacky; the woods entrance had a pointless gate:**
  - two SpriteCook sheets (24 credits, 500 left), sliced by
    `slice_spritecook_grid.gd` (now with 2x2 sheets and an "opened" derived
    sprite): a straight double gate, closed and open, a lantern trail post,
    a straight rail fence, a top-down vertical fence run and a padlocked
    edge-on gate;
  - shortcut gates across north–south trails are fence, gate, fence at chest
    height (the gate leaves swing back when opened). Across east–west trails
    they are a top-down fence run with the padlocked gate in the middle
    (just its posts once open). Before, a row of tiled angled gates or
    sparse angled sections;
  - the stray gate mid-trail at the east entrance became lantern posts on
    both sides of all four trail mouths (lit while camp is safe), with the
    plaque moved to the trail edge.
- **Boat landing water was non-existent:**
  - the lake was solid on layer 1, so the sight mask treated it as a wall
    (and it cast a black shadow). Water is now on its own layer
    (`CampPlayer.WATER_LAYER`): bodies collide with it, but sight, light and
    voice rays cross it;
  - `LakeWater` draws it with `lake_water.gdshader`: depth shading from the
    bank, drifting pixel wave dashes, a slow swell, lapping foam, rings
    around the pilings and glints where light falls;
  - a muddy bank and a lantern at the end of the pier.
- **Lobby voice visuals:** a mic meter (mode, level, open-mic threshold) by
  the title, and a speaker meter per roster row lit by that player's voice.
- **Hard to hear in the woods:**
  - the muffle (any blocked line, and trees block nearly every line in the
    woods) was a 900 Hz low-pass; it is now 2.4 kHz;
  - range rises from 420 to 560 px with gentler attenuation (0.6, was 1.4)
    and panning strength 0.4;
  - the Voice bus levels speakers (compressor plus limiter), so a quiet
    microphone, the likely cause of "friends can't hear me but I hear them",
    is lifted;
  - music, ambience and effects duck while anyone is heard.

**Verification (macOS):**
- `design_feedback.gd`: 52/52.
- Rerun after the changes: offline_slice 65, chase_props 46, chase_toolkit 29,
  woods_replay 443, surround_world 101, killers_modifiers 32, night_phases 43,
  content_expansion 443, roles_abilities 33, night_events 31, forest_hunt 87,
  barriers 32, field_escapes 58, signal_fire 31, navigation_aids 45; all 0
  failures.
- Three tests changed for the new rules:
  - `offline_slice` waits through the stalker's 4 s cooldown;
  - `chase_props` opens the camp, since its hiding and door scenarios are
    second-half ones;
  - van start now opens the camp, which `signal_fire` expects.
- `verify_voice.py`: 24 + 8 + 13 checks.
- `verify.py` (import, startup, every script parse and all suites,
  `design_feedback` included): all 140 steps passed.
- Gates, entrances, water and lobby checked in captured frames.

**Screenshots:**
- After a normal-darkness capture the water was brightened (shallows and
  crests lifted, glints stronger but sparser) and the pier lantern widened
  (220 px, energy 1.25); `field_escapes.gd --capture` still passes 58/58.
- The README boat, boathouse, lake-thing, Groundskeeper (reframed so he is
  actually in view; the old frame showed Bigfoot) and lobby screenshots were
  retaken; the lobby comes from `verify_network.py --mode camp --players 2
  --graphical` (host 107, client 29, late joiner 2 checks).

## 2026-10-17 — Import crash on Linux and Windows: voice library kept out of the editor

The friends' machines still failed after the launcher fixes. Their logs showed
the import itself crashing (`Program crashed with signal 8`, `FATAL: Index
p_index = 1 is out of bounds (size() = 0)`), leaving 314 of 325 assets
unimported. That was the real cause of the earlier missing-`.ctex` reports, not an
editor closed mid-import. Reproduced on the user's Ubuntu 26.04 machine
(genesect) with the Snap Godot 4.7.2 .NET build and with the standard
official 4.7.2 Linux build. Isolated by removing parts of a copy: an empty project and the project
without `addons/twovoip` import cleanly. The standard build's backtrace ends inside
`libtwovoip.linux.template_debug.x86_64.so` (the release library crashes
too). The editor crashes on every start while the extension is listed, but the
game loads it and voice works. TwoVoIP 6.6 is already the latest release.
- `addons/twovoip/.gdignore` hides the addon from the editor; the Voice
  autoload loads it at runtime with `GDExtensionManager.load_extension`.
- Both launchers drop the twovoip line from `.godot/extension_list.cfg`
  (older caches list it, and the editor loads that list before scanning).
- `godot_cli.py` also finds the Ubuntu Snap command `godot-4`.
- README troubleshooting quotes the crash; the multiplayer guide explains why the
  addon is hidden from the editor and notes that exports must ship it explicitly.

**Verification (genesect, Ubuntu 26.04 x86_64, Snap Godot 4.7.2 .NET):**
- fresh copy with a stale extension list: `python3 tools/run_game.py` found
  `godot-4`, imported all 650 files with no crash and started the game;
- `Voice.available` is true and the extension appears as loaded at runtime;
- `voice_chat.gd`: 24/24 checks.

**Verification (macOS):**
- `verify.py` passed every step;
- the launcher emptied the stale list, imported and reached `menu_ready` with
  0 errors;
- `verify_voice.py`, using the runtime-loaded extension, passed its two-process
  round (24 + 8 + 13 checks);
- `git diff --check` is clean.

**Not verified:** Windows. Its library is the same TwoVoIP build, and the friend's
symptoms match, but the fix has not run there.

## 2026-10-17 — Launchers always import (partial-import report)

After the first fix the Windows friend still saw missing `.ctex`/`.mp3str` files
(UI art, music) although scripts now parsed: the `.godot/` cache existed but its
import was incomplete (likely an editor closed mid-import), and the launcher
only checked that the cache folder existed. Both launchers now run Godot's
import before every launch; it processes only new or changed files (2.4 s when
up to date here). `run_game.py` also lists assets whose imported file is missing,
warns if any remain afterwards, and accepts `--no-import`. All 1,118 tracked
assets have their `.import` files committed.

**Verification:** deleted three imported files to mimic a partial import:
`missing_imports()` found 3, the launcher re-imported them and reached
`menu_ready` with 0 missing and no errors.

## 2026-10-17 — Fresh-clone launch fix (Windows report)

A friend on Windows got parse errors for every global class (`CampProfile`,
`RoundPlan`, `CampPlayer`…) and missing `.godot/imported/*.ctex` textures. Cause:
the game was run before Godot had ever imported the project, so the untracked
`.godot/` cache (class list and imported textures) did not exist. Not a Windows
or code bug: reproduced on macOS by deleting `.godot/`.
- `tools/run_game.py` now imports automatically when the cache is missing
  (`--reimport` forces it), and finds versioned `Godot_v4*` executables beside
  the project, in Downloads or on the Desktop.
- New `Play (Windows).bat` launcher (uses Python if present, otherwise finds
  Godot itself and imports on first run).
- README quick start stresses waiting for the first import and gains a
  troubleshooting section quoting these errors.

**Verification:** with `.godot/` removed, `python3 tools/run_game.py --headless
--quit-after 30` imported and reached `menu_ready` with no script errors. The
`.bat` file could not be executed here (macOS).

## 2026-10-17 — Voice fix: received voice was decoded but never played

The user tested two local sessions with the mic on: audio was picked up but
nothing was heard. Cause (in our code, not their setup): TwoVoIP's
`AudioStreamPlaybackOpus` starts paused at an end mark (`bufferstreamend = 0`),
and `VoiceChat` never called `mark_end_opus_stream(true)`, so decoded voice sat
in a paused buffer and the mixer output exact silence. The old tests only
counted decoded frames. Fix: clear the mark once the jitter buffer is queued
(per utterance). Lobby voices are now centred on the screen rather than placed
at the world origin, so they play at full level without a camera.

The two-process test now samples the mixer's output peak for the other peer:
on the old code it was **0.00** (the user's symptom); with the fix **0.07**
(the synthetic tone is partly suppressed by RNNoise, as noise). Human listening
on real hardware is still the final check.

**Verification:** `verify_voice.py` passes (codec 25 checks, host and client
round trip with output peak); `verify.py` 137/137.

## 2026-10-17 — Ranger checkpoint and escape screenshots refreshed

The user noticed the ranger checkpoint screenshot looked hand-drawn. It was a
stale capture from the previous session, and the live gate still drew its two
floodlight posts as plain lines (the open barrier arm already used the
SpriteCook sprite). The posts are now the SpriteCook lamp post with a glow
when the circuit is powered. All 13 boat, gate and radio screenshots used in the
README and guides were retaken from the current build.

Retaking them exposed a regression from the depth-sorting change: the radio
mast, substation and other escape structures are drawn on a silhouette layer
above the sight mask, and their new world sprites had lost that (the mast
vanished into the dark). `StandingProps` now copies the layer's material and
brightness and keeps silhouette sprites above the mask, dropping them into depth
order only while your survivor stands in front of and overlapping them. The
radio readability test also hides the new sprites in its control frame.
One graphical field-escapes run showed five lake/boat timing failures that did
not reproduce (headless and a repeat graphical run both passed).

**Verification:** `verify.py` 137/137; graphical `field_escapes` and
`radio_rescue` captures 0 failures; `verify_network.py --players 2` (below).

## 2026-10-17 — Heartbeat replaces the monster readouts

Per the user: no on-screen indication of which monster is nearby or which is
hunting you. Removed the HUD lines ("<SPECIES> NEARBY", "FOOTSTEPS NEARBY · KEEP
QUIET", "SPOTTED · RUN!") and the "!"/"?" bubbles over hunters (the witch's
casting ring and stun stars remain, as power telegraphs). The heartbeat now
carries it: any enabled creature within 300 px, even behind trees, brings a
quiet beat (0.35–0.7 gain) that speeds from 0.8× to 1.0× as it closes; a hunter
with you in sight (chasing you) brings full volume at 1.45×. Journal sightings
still record.

**Verification:** `audio_polish.gd` checks the fast/loud seen beat, the slow/quiet
nearby beat, the fade when nothing is near, and an empty HUD readout;
`verify.py` (below); `verify_network.py --players 2`.

## 2026-10-17 — Twenty-seven new sounds; depth-sorted structures

**Audio.** The user added 27 MP3s, two with instructions in their names. Per those:
the gravel footsteps were cut to the first 6 s and the breathing to the first
half (5.5 s), both renamed to clean cue files with an 80 ms fade; the heavy rain
loop lost 0.4 s of trailing silence so it loops seamlessly. All 50 cues are in the
manifest with measured gains. New playback: thunder after lightning, storm and
rain loops, van start, sabotage car alarm, snare clang and chain, gift bells,
hunting horn, pyre whoosh and blaze loop, boat outboard, generator hum, door
creak, locked-cache rattle, owl/wind/eerie ambience, gravel and mud footstep
loops, held breath and panting, a chase music layer, and five new creature
voices (including the Groundskeeper's growl). Event sounds trigger from
replicated state so every peer hears them; alarm-type cues carry 400–1,400 px.

**Structures from every side.** A four-side capture of 12 structures showed
tall props painted flat under the survivor (standing north of the relay mast put
you in front of its legs). New `StandingProps`: canvases that opt in turn
`PixelArt.draw_standing` props into depth-sorted Sprite2Ds in the level's
y-sorted world (hidden again when their canvas stops drawing them, e.g. an
opened gate), and a prop hiding your survivor fades to 42%.

**Verification:** `verify.py` 138/138 (new: every MP3 registered and every cue
loads; thunder, storm rain, chase layer, held breath, van/snare/gift sounds,
road footsteps, positional generator; pyre is a depth-sorted sprite that turns
see-through); `verify_network.py --players 2` 375 assertions, 0 failures.

## 2026-10-17 — Gameplay clips in the README

The user asked for clips "showing like storms, certain interactions" so people
understand the game. `tools/capture_clips.gd` plays eight scripted moments in
the real game (storm, werewolf chase and flare, flash-stun, hiding, door slam
and break-in, Groundskeeper snare, van start, Signal Fire) and saves 15 fps
frames; `tools/build_clips.py` turns them into native-size GIFs with ffmpeg
(13 MB total). The README's new "See it in action" section shows them with
captions. Staging is honest about two shortcuts: the night is brightened a
little, and in the door clip the stalker is nudged the last few pixels onto the
porch (navigation stops just short) before the real break-in rule runs.

Storms now show on screen: heavy slanted rain on every storm (not only rain
nights) and a full-screen lightning flash, alongside the existing world flash.

**Verification:** `verify.py` 136/136; clip frames inspected.

## 2026-10-17 — Everything on screen from SpriteCook (fifth art batch)

The user asked whether every image was SpriteCook-made "including backgrounds"
and approved 196 credits to "make the game awesome looking". An honest audit
found that all image files were SpriteCook art but many things were still drawn
in code. Eleven generations (**132 credits; 524 left**) replaced them:
- World: fences and gates (tiled sprites), plank doors with hinges and a broken
  door sprite, fallen woodpile logs, helipad, raised ranger-gate arm, bush
  hiding spots, the "THE WOODS" gate, and seeded trail-side dressing (26
  pieces) beside about one in ten straight trail sections.
- Effects/markers: flare, blood trail and wound, noise tin, hex bolt, thorn
  patches, Scout mark, lake ripple, stun stars, alert/suspicion bubbles over
  hunters, help sign over downed survivors, held items drawn with their icons,
  and skyline/pin icons.
- Interface: nine-slice wooden panels, buttons, belt slots (selected state) and
  the field-map frame via `CampStyle.art`; illustrated loading, survivor
  selection (with portraits) and lobby backgrounds.
- Walk cycles: mid-stride edits of the survivor, stalker and Groundskeeper
  grids feed real stepping frames (survivors mirror the front/back stride; the
  killers do not, so their weapon stays in one hand).
- `tools/slice_spritecook_components.gd` slices sheets by connected shape when
  pieces overflow their grid cells (UI, portraits). Fixed: the loading art drew
  blank when loaded mid-draw (now loaded once), and a belt-slot meta lookup error.
- Still code-drawn by design: light, fog/rain, flashlight cones and sparks
  (animated effects), the signpost text boards and HUD text.

**Verification:** `verify.py` 135/135; `verify_network.py --players 2` 375
assertions, 0 failures; screenshots retaken.

## 2026-10-17 — README reorganised for new players

The user found the README hard to use ("unsure how to play the game and what it
looks like"). It now opens with a pitch and four screenshots, a contents list,
"What kind of game is this?", an install-and-play quick start (Godot download,
Download ZIP or git, Import, F5), an illustrated eleven-step first night, the
controls, how to win and lose, and beginner tips. The detailed reference follows
(co-op and voice, modes, the night, score, killers, escapes, survivors, items,
creatures, the world, sound, sites, replay), then screenshots, art and a
refreshed development summary (134 steps, 375 network assertions, voice suite).
Claims were checked against the code; links verified.

## 2026-10-17 — README screenshots retaken; results and journal panels fit

- Retook every README screenshot with the new art (one graphical suite at a
  time) and added a "New this update" gallery from the new
  `tools/capture_showcase.gd`: Signal Fire, Groundskeeper and snare, Scout mark,
  Lost Camper, Stalker's Gift, van finale, results with score, Camp Journal.
- The captures exposed two overflow bugs, both fixed: the results panel (score,
  awards and badges pushed MAIN MENU off-screen) is now wider and compact, with a
  "YOU GOT OUT" heading now that there is no dawn; the Camp Journal body is a
  scrollable rich-text box.

**Verification:** `verify.py` 134/134 (two temporary probe scripts removed, one
capture tool added); all graphical capture suites 0 failures; README links checked.

## 2026-10-17 — Art pass: no more boxy ground, placeholders or flat roofs

The user asked that every boxy graphic be replaced ("no cheap looking ground")
while keeping credits in reserve. An audit capture of every area (camp, 14
regions, escape sites, new props) found the worst offenders: flat grey Ranger
Road, grid-tiled court floors, striped orchard ground, hard straight path edges,
visible grass tiling, flat roofs, line-drawn walls, and placeholders (pyre,
snare, gift crate, a tinted stalker as the Groundskeeper).

- SpriteCook: four generations, **48 credits (704 → 656 left)**: Groundskeeper
  sheet (edit of the stalker grid), 16 night props, 16 ground decals, 9 seamless
  surfaces. Recorded in `spritecook-assets.json`; sliced/imported by
  `tools/slice_spritecook_grid.gd`, `import_spritecook_textures.gd` and the new
  `import_spritecook_groundskeeper.gd`.
- Ground: seeded decals soften every camp road edge and woods trail edge and
  break up tiling; camp grass uses the calmer lawn; Ranger Road is asphalt with
  crumbling shoulders; landmarks use their own floors (mossy flagstones, court
  tiles, orchard soil, quarry gravel) with sprite dressing instead of speckles
  and survey circles; the bog has textured pools and a plank boardwalk.
- Buildings: gable roofs with lit and shaded slopes, ridge cap, eaves, chimney,
  awning and subtle moss; plank interior walls, mullioned windows, plank
  thresholds; plank docks.
- Fixed: the Groundskeeper sheet drew as a white box when loaded at draw time;
  both killer sheets are now preloaded constants. Stacks of identical pickups
  show one label.

**Verification:** `verify.py` 135/135; `verify_network.py --players 2` 375
assertions, 0 failures. Evidence: [art batch 4](evidence/spritecook/README.md).

## 2026-10-17 — Story events, build-ups and the creature audio revamp

The user noted creatures "do not really make that much noise".

- **Audio revamp** (`CampSoundscape`): creature calls carry 560 px (was 160)
  with a gentler roll-off; chasing creatures call every 3.5–5s (louder),
  wandering ones every 6–12s; monster footsteps carry 240 px (was 110), louder and
  pitched by size; the headline killer screams in a chase and growls while
  investigating; a distant chorus (every 18–35s) places a far creature's call
  toward it within 480 px; voice pool 12 → 20. AI hearing is unchanged.
- **Story events** (`NightEvents`, two of three per night in seeded phases):
  The Hunt Begins (horn; 60s of roamers converging on the last inner-ring loud
  noise), The Stalker's Gift (pinned bait crate; supplies plus a bell the killer
  hears from anywhere), Lost Camper (pinned NPC who follows the first survivor
  home on the navmesh, panics when chased, +medkit and +250 score).
- **Build-ups:** each director peak flickers the focus survivor's flashlight and
  plays a distant call from the steered creature's direction.
- Found and fixed while testing: the horn's own noise overwrote the "last loud
  noise" it should point creatures at. Rules `lnac-net-15`.

**Verification:** `night_events.gd` 22 checks; `verify.py` 132/132;
`verify_network.py --players 2` 375 assertions, 0 failures; `verify_voice.py`
passes.

## 2026-10-17 — F8 score, Daily Night, Camp Journal and merit badges

- `CampProfile` (local `user://profile.cfg`; test runs use `profile_test.cfg`)
  keeps nights, escapes, routes, best score per seed, daily bests, creature
  sightings and twelve merit badges.
- Expedition results show **score and grade** (escape, rumoured route, relics,
  notes, rescues, sightings, ×1.15 per modifier), new badges and the best score
  for the seed. The host computes the card; clients receive it and record their
  own local profile.
- First sightings (creature in sight within 180 px, or the killer within 155 px)
  unlock bestiary tips and announce "New journal entry".
- Menu: **DAILY NIGHT** mode (seed = date) and a **CAMP JOURNAL** panel. The right
  column was tightened to fit both.
- Not done: cosmetic/role unlocks and the campaign (they need profile data the
  lobby can validate).

**Verification:** `meta_progress.gd` 27 checks; `verify.py` 129/129;
`verify_network.py --players 2` 375 assertions, 0 failures.

## 2026-10-17 — F7 headline killers, stalker escalation and night modifiers

- `RoundPlan` seeds a **headline killer** (Stalker or H01 **Groundskeeper**) and
  **0–2 modifiers** (Blood Moon, Dead Batteries, Fog Bank, Silent Night,
  Generous Woods, Lone Wolf) on separate RNGs, announced at Dusk and in the pack.
- **Escalation tiers** follow the night phase: Dusk keeps the killer's chases
  inside the 1,600 px inner ring; Deep Night extends search memory 50% and arms
  one **van sabotage** (an unguarded van loses its last part, dropped and pinned
  "STOLEN" in that part's region, with an alarm); the Witching Hour breaks doors
  1.5× faster and **cuts the generator once** if unguarded. The killer walks to
  the van/generator normally; nothing teleports.
- **Groundskeeper snares** (`Snares`): set on walked trail cells while patrolling
  (max 4 armed, 150 px apart), 4s hold with a loud rattle, instant teammate
  release or quiet disarm on E, glint within 90 px of a flashlight. Snares and
  the snared timer replicate. Groundskeeper art is a tinted stalker until the
  art pass. Rules `lnac-net-14`.
- Correction to the F5c entry: `signal_fire.gd` has 29 checks, not 25.

**Verification:** `killers_modifiers.gd` 32 checks; `verify.py` 126/126;
`verify_network.py --players 2` 375 assertions, 0 failures. The active-AI
expedition bot passes on seed 42's real rules (`woods_replay` uses
`--no-modifiers` for its baseline recipe checks).

## 2026-10-17 — F5c Signal Fire, rumoured escapes and the van finale

- **One rumoured escape per night.** `RoundPlan.escape_options` is the van plus
  one seeded secondary (Radio Rescue, Boat, Ranger Gate or the new Signal Fire).
  Only tonight's parts spawn (the substation fuse appears for radio or gate,
  which share it). The Dusk message names the rumour and T cycles tonight's plans
  only. Absent escapes have no prompts, progress or extraction. Fixtures and
  network peers pass `--all-escapes` to exercise every escape on one seed.
- **Signal Fire.** Two kerosene cans and a flare gun in three directions (seeded
  among village/observatory, bog/rail yard, graveyard/chapel), carried without
  belt slots to a pyre on the White Stone Quarry rim. Lighting starts a 45s
  hold-out: a big firelight, a 1,500 px beacon and the stalker called from
  anywhere, repeating every 6s. Standing survivors in the 110 px ring are
  rescued with downed teammates. Counts as escape progress; replicated.
- **Van finale.** Expedition departures take 20s (Quick Camp stays 8s); the
  engine start calls the stalker and roars to 1,200 px, then revs every 5s.
- Fixed a voice robustness bug found by the network run: speaker routing could
  assign a just-freed survivor to a typed variable at round end.

**Verification:** `signal_fire.gd` 25 checks; `verify.py` 123/123;
`verify_network.py` woods 236 and camp 133 assertions, 0 failures (the boarding
wait now allows the 20s departure); `verify_voice.py` passes.

## 2026-10-17 — F6a Roles 2.0: abilities, item passing, team hooks, awards

- New `SurvivorAbilities` node (host-validated, replicated): X uses the role's
  ability. Jock **Second Wind** (stamina + 10% sprint 2s, once per phase),
  Grease Monkey **Jury-Rig** (2/night: barricade a door 8s so pushing makes no
  progress, or silently restart dead power; the generator takes priority during
  a blackout), Scout **Mark** (30s cooldown; tags the creature/cache/site faced and
  in clear sight for 6s; never an unseen one), First-Aid Kid **Patch** (2/night,
  self or adjacent teammate, no medkit), Quiet Kid **Hold Breath** (6s silent
  sprinting, half breath drain hidden; 45s), Overprepared **Unpack** (once: four
  supplies on the ground for the team).
- H hands one held supply to an adjacent standing teammate with belt room.
- Team hooks: Jock hauls the motor at full walk; Scout starts knowing one extra
  part's region; Quiet Kid leaves no blood; two survivors restart the generator
  quietly (solo stays loud). Barricaded doors show crossed planks.
- Host-tracked stats give results-screen awards (Never Left Behind, Most Flares
  Wasted, Bait, Hid In A Locker For Two Minutes, Pack Mule, Always Gets Caught,
  Show-Off), replicated to clients. Selection cards and HUD show each ability.
- Rules `lnac-net-13`. Ghost wisps deferred: under current rules nobody is a
  spectator while the round continues.

**Verification:** `roles_abilities.gd` 33 checks; `verify.py` 120/120;
`verify_network.py --players 2` 369 assertions, 0 failures, including a guest
Jury-Rig accepted by the host and replicated. The boat test now runs as Grease
Monkey, since the Jock no longer slows down with the motor.

## 2026-10-17 — Opt-in proximity voice chat (TwoVoIP)

The user cloned TwoVoIP into the project and asked for proximity chat, tested if
possible. The clone's own `.gdextension` (no binaries) broke project import, so
the clone was moved beside the project (`../two-voip-godot-4`, as allowed) and
only the official v6.6 release's desktop libraries plus the MIT licence were
vendored into `addons/twovoip/` (about 50 MB; macOS universal, Windows/Linux x86_64).

- New `Voice` autoload (`scripts/network/voice_chat.gd`): off by default; push to
  talk (hold **B**) or open mic; mono 48 kHz Opus at 24 kbit/s in 20 ms frames
  with RNNoise and Speex AGC; unreliable-ordered RPCs on ENet channel 3 through
  the host relay; 400-byte and 75-packet/s per-peer limits; three-packet jitter
  start; single-loss FEC.
- Routing: lobby everyone; in a round, alive/downed/boarded survivors hear each
  other positionally up to 420 px (low-pass when a wall blocks sight), escaped,
  dead and left-behind players share a ghost channel the living never hear.
  Monster AI never hears voice. HUD shows who is talking and your mic state.
- Settings/Esc/lobby mixer: Voice volume, MIC mode, MIC GAIN and a status line.
- **macOS finding:** with `audio/driver/enable_input=true` in the project, Godot's
  CoreAudio start-up blocked (timed out) waiting on the microphone permission
  prompt, even with voice unused. The project now keeps input off; choosing a
  voice mode writes the setting to `user://engine_overrides.cfg` (via
  `application/config/project_settings_override`), so only players who opt in
  start the microphone, after one restart. Verified CoreAudio start-up no longer hangs.

**Verification:** `python3 tools/verify_voice.py`: `voice_chat` 24 checks (real
Opus encode/decode, FEC, routing, limits, settings); two-process ENet test: 73
packets each way, about 70,000 decoded frames per side, then a live Quick Camp
round with positional, out-of-range and ghost routing (client 7, host 12 checks).
`python3 tools/verify.py` 119/119; `verify_network.py --players 2` 361
assertions, 0 failures. **Not verified:** a real microphone and human listening.
The unattended probe could not answer macOS's permission dialog. Internet
latency and encryption (ENet voice is unencrypted) are also unverified.

## 2026-10-17 — Night paced by progress, not the clock

The user asked to "remove the fixed time requirements… make the whole process
take long, but move at a natural pace."

- `NightClock` phases now follow **escape progress**: the best fraction of any
  escape's steps (van parts; radio power, transmit and three signals; boat parts;
  gate codes and power). Nightfall at 20%, Deep Night at 50%, Witching Hour at
  80%. Radio reveals stay tied to phases, so each installed part deepens the night
  and unlocks the next: a long chain that never waits on a clock.
- A stalled team **drifts** one phase after 12 quiet minutes, up to Deep Night
  only; the Witching Hour comes only from real progress.
- Removed every 40:00 gate (radio transmit, boat launch, gate opening) and the
  60:00 **dawn** deadline and rescue (`dawn()` deleted). The heading shows elapsed
  time instead of a dawn countdown.
- Storm/blackout events are tied to phases with a seeded delay. A phase the team
  races through drops its event rather than stacking several at once (caught
  by `content_expansion`, which installs every part immediately).
- Dread climbs with time spent in a phase; in the Witching Hour it has no ceiling.
- Tests updated to drive progress (`force_phase`, installed parts) instead of
  clock jumps. `night_phases` now checks drift timing, part-driven phases, that
  drift never reaches the Witching Hour, and that there is no deadline after two
  more hours.

**Verification:** `python3 tools/verify.py` 116/116 steps (headless, run with
`nice` after the user's computer crashed during an earlier heavy parallel run).
Night phases 43 checks, Radio Rescue 34, Field Escapes 58, expedition bot 227
with every enemy active; `verify_network.py --mode all --players 2`: 6 processes,
361 assertions, 0 failures. Human pacing is still unmeasured.

## 2026-10-17 — F5b Boat, Ranger Gate and a matched SpriteCook prop sheet

**Completed and published on 17 October** after review by the next session. The
remaining blocker (the active-AI expedition bot running out of supplies and being
downed) was fixed in the bot, not the game: it now steps aside for supplies within
120 px in plain sight (woods only, skipping any it cannot reach) and uses a
medkit through the belt when wounded and not chased. No resources are granted,
no AI is disabled and the seed is unchanged; it passes with 227 checks.

Continued the user-approved F5 track; normal-speed human playtests remain
explicitly deferred. SpriteCook MCP became available during this increment.
Used the workflow/generation/polish skills, verified the owned camp-object style
reference against its local hash, and generated **one 16-prop NB 2.1 sheet at 1K
for 12 credits (716 → 704)**. Inspected saved/preserved alpha, kept cutoff 130,
and reused the same output without paid animation, regeneration or cleanup.
Asset IDs/hashes and crop reproduction are in `spritecook-assets.json` and
`tools/slice_escape_props.gd`; signed download URLs are not stored in the repo.

- Added Logging Camp, Lakeshore Boathouse and Ranger Road/Bridge, bringing the
  finite forest to fourteen regions. New art replaces flat F5 transformers,
  breaker/mast and adds the boat/motor, shore building, ranger booth/barrier,
  logging workshop/logs, pier, bridge, Lake Thing, marine fuel and code notes.
- Boat requires a unique motor from logging, marine fuel from the Rail Yard and
  a drain plug from the Observatory, spanning three spokes. Objective items use
  no belt slots, install once, and drop through existing reachable-ground rules.
  Motor carriers walk at 75%, cannot sprint/vault, and G sets the motor down
  before belt supplies. An adjacent standing held-E helper restores full walk
  without sprint. Host-derived assistance replicates to peers.
- After 40:00 the fitted boat starts a 25s launch. Three fixed dock strikes warn
  for two seconds, use ordinary wound/grace rules and can be dodged/interrupted
  by a nearby visible flare. Lake Thing is bounded pressure, not a new roamer.
- Gate fragments rotate across three E/S/W regions. The shared substation plus
  local breaker powers road lamps. A four-second host-owned hold after 40:00
  opens the physical arm on all peers. Survivors run north; first bridge arrival
  starts an eight-second team window. Gate alarm stimuli attract the existing
  stalker through normal travel, with local hearing bounded for other creatures.
- Boat radius is 80px; bridge radius is 64px. Standing/unhidden arrivals escape,
  any successful extraction rescues connected downed teammates, and other
  standing survivors are left behind. Route-specific results replicate.
- T cycles four local objective pages without map/text overlap; Quick Camp stays
  van-only. Expanded snapshots retain bounded packet chunks. Rules `lnac-net-12`.
- Repeated graphical rounds exposed a radio timer capturing an already-freed
  source. Read the audio design and replaced the callbacks with named round-owned
  methods plus a weak source reference, preserving playback timing. A regression
  also caught Ranger Road/substation apron overlap; shortened the road clearing
  by one cell while preserving the 1,000px run and native connectivity.
- Updated README/items, illustrated walkthrough, full-map example, biome/monster
  plan status, brief, architecture, milestones and multiplayer/testing docs.
  Signal Fire, primary/rumoured selection and revised van finale remain pending.

Execution evidence: [Boat/Gate verification](evidence/boat_gate/README.md).
No human pacing, real cross-machine Internet, new audio-file/listening, voice or
export-platform acceptance is implied by these automated tests and captures.

## 2026-10-17 — F5a Radio Rescue and two new regions

User approved F5 work and explicitly deferred normal-speed human playtests.
Implemented one coherent slice: Radio Rescue alongside the van in expedition;
Boat, Ranger Gate, other finales and primary/rumoured-escape rotation remain
future work. Quick Camp keeps its original van flow. Reused existing SpriteCook
art/materials with original pixel-drawn machinery; no new generation credits.

- Added seeded north Power Substation/east Radio Relay Station clearings, an
  east-spoke approach, textured service yards, transformers, insulators, fuse
  cabinet, mast, platform, ladder, guy wires and bounded collision/navigation.
  Only anchored machinery rises above floor fog; creatures/terrain stay hidden.
- Added one emergency fuse at the mill (separate objective inventory; drops on
  down/disconnect), dedicated persistent rescue power, and a six-second relay
  hold after 40:00. Release, distance, down/disconnect and operator changes reset
  incomplete progress. Camp blackouts cannot undo the rescue circuit.
- Three persistent flare holders and a three-flare chapel stash prepare rescue.
  E at the landing centre explicitly starts a 40-second holdout. Signal noise
  uses ordinary bounded hearing without teleporting enemies or breaking leashes.
  Standing/unhidden survivors within 96px and clear sight escape; any successful
  rescue includes connected downed teammates anywhere. Other standing survivors
  are left behind. First completed escape ends the night.
- Added a local T objective page, region markers/signs, synchronized signal
  lights/progress/countdown and escape-route results. Rules `lnac-net-11`.
- Updated README item/escape rules, illustrated guide, plan/brief, architecture,
  testing and multiplayer docs. Rebuilt the full-map example with eleven
  numbered regions and current seed-42 spawn positions.

Verification: `python3 tools/verify.py` passed all 109 steps with zero
errors/warnings; final headless import/startup also exited 0 without diagnostics.
Focused radio tests passed 34 headless / 36 graphical assertions, including
actual rendered structure pixels. Independent ENet runs passed 170 assertions
(two-peer graphical Woods), 276 (four-peer Woods) and 129 (two-peer Quick Camp).
Checked local documentation/image links and `git diff --check`.
Execution evidence is collected in [F5a evidence](evidence/radio_rescue/README.md).
The first regression run exposed an old test indexing a relic action in every
region. The two rescue sites deliberately have objective actions instead; the
fixture now checks that distinction and skips relic assertions for those sites.
No player-facing workaround or generic relic was added. Normal-speed human
pacing/balance and cross-machine Internet remain unverified as requested.

## 2026-10-17 — Readable north/south forest borders and local canopy clearance

Read the latest brief, fun overhaul direction and preceding SpriteCook/tree-line
work before changing presentation. Confirmed the upright tree sprites and
flat-ground light/shadow/sight layers made north-facing edges disappear while
south crowns piled over the trail. Reused the existing sprites; no image credits
spent or new external art. Cosmetic jitter now includes the run seed.

- Staggered 32px trunk rows, varied 60/75/90% crowns, pine/spruce weighting,
  occasional birch and rare snags replace the uniformly dense 20px rows.
  Cached anchors sample multiple trail sides, preventing missing edge rows
  when the first anchor belongs to the hidden side.
- A view-local foliage surface layer catches visible flashlights/flares and
  adds front-edge bracken. An original unshaded shader uses existing sight-ray
  depths to fade outer tips within 60px of the first surface. It never redraws
  terrain or entities over fog. Native walls, light occluders, navigation, AI
  sight, game progression and network rules remain as before.
- A close-wall walking control caught the old lower canopy still hiding the
  avatar under the surface fade. Sprite/body bounds now handle north overlaps
  too, and the local fragment opening clears foliage around the body. A small
  mask opening (under 29px) and 25px local glow preserve the known observer's
  silhouette; both remain inside the forest-wall/peek budget. Hidden neighboring
  floor/monster and native shadow controls still pass.
- Smooth woods lookahead is bounded at 24px horizontal/down, 32px north; it
  works for host/client replicas, keeps the player above the belt and recenters
  in camp. No camera or foliage state is networked.

Verification on macOS arm64 / Godot 4.7.2:

- `python3 tools/verify.py`: **104/104 steps passed**, zero errors/warnings,
  including import/startup, native navigation, active solo rounds and overhaul
  regressions. Added the new headless/optional graphical treeline case.
- Actual graphical cardinal/walking test: **20 assertions**, all pass. Four
  facing directions at normal fog/night exposure, lit/unlit photos, foliage
  pixel controls, hidden monsters, native collision, camera/HUD bounds, recenter
  and visible avatar pixels at a north wall. The avatar negative control hides
  only its own drawing, preserving lights and foliage.
- Graphical sight: **7 assertions**, hidden floor luminance 0.0 vs control 0.187.
  Graphical shadows: **12 assertions**, no adjacent-trail light gain, with
  positive leakage after disabling native occluders.
- Two actual graphical ENet peers/both modes: **273 assertions / 6 processes**,
  zero failures/errors/warnings, including shared light/flare pixel checks.
- Final import/startup rechecked after shader/overlap refinements. Documentation
  links/anchors/images and `git diff --check` checked before publishing.

Graphical fixtures now wait for loaded worlds and drawn frames/camera caches;
old fixed-frame waits produced stale empty views. A sight positive probe moved
from a trunk/shadow to actual adjacent floor; HUD/weather overlays are isolated
for that strict test. The normal before/after photos retain HUD/weather and
never boost ambient light. Representative lit/unlit directions and walking
captures opened for inspection. Point FPS samples varied with concurrent work
(37–145), not a performance benchmark or recorded human frame-rate acceptance.

Updated README north/south screenshots, architecture, testing and brief. Matched
[before/after images and raw evidence](evidence/forest_treeline/README.md) are
preserved. Human play-feel/pacing, other-platform exports and real cross-machine
Internet acceptance remain unrecorded; existing overhaul rules were retained.

## 2026-10-17 — Forest tree line along every trail; menu buttons on the right

Playtest feedback: trail edges looked like a rigid black line with a few tree
tops poking up, not a surrounding forest. The title-screen buttons also covered
the new art.

- **Tree line.** `woods_terrain.gd` replaces the 32 px checkerboard of canopies
  with trees on a jittered 20 px grid inside the forest walls: every tree
  within 44 px of a trail is kept (the edge line), and one in three deeper in.
  Trunks always stand inside the wall, so collision and navigation are
  unchanged. Shrubs fill the gaps between trunks along each edge, and the
  forest floor under the walls is shaded darker.
- **Softer sight mask.** `WoodsVisibility` now lets sight reach 12 px into the
  wall and then fades to black over 18 px, instead of cutting off at the wall
  face. Corridors are separated by walls at least 64 px thick, so this never
  reveals the next trail. Edge trees whose own patch of trail is in sight are
  redrawn whole above the mask, so the forest rises as a silhouette instead of
  being clipped. Monster visibility (`can_see`) is unchanged.
- **Menu.** Host/Join Co-op and Settings joined Enter the Night, Controls and
  Quit in the right-hand column (`Menu/Online`, `Menu/Settings`), so the left
  side shows the title illustration. The translucent panel now spans the column.

**Verification:** `python3 tools/verify.py` 101/101 steps;
`verify_network.py --mode all --players 2` passed (woods host 109 checks,
client 29, 0 failures). Not yet verified: a human playtest of the tree line at
normal night darkness and frame rate.

## 2026-10-17 — README screenshots retaken with the new art

The user noted the README images predated the SpriteCook passes. Every README
screenshot was retaken from the current build and stored in
`docs/screenshots/` with a source table; older images in `docs/evidence/` stay
unchanged because earlier log entries cite them.

- `surround_world.gd --capture` now also saves `landmark_<region>.png`: each
  region's centrepiece at gameplay zoom with the HUD hidden. These replace the
  zoomed-out region and biome shots in the README, where the new bell frame,
  well, cauldron, crypt, waterwheel, dome, signals and columns were too small to
  see.
- The Ranger Lodge shot (too dark to show furniture) became the mess hall.
- Captions now describe what each new image actually shows.

**Verification:** `python3 tools/verify.py` 101/101 steps. The graphical captures
came from `verify.py --graphical` plus direct `--capture` runs of
`camp_upgrade`, `woods_replay`, `forest_hunt`, `surround_world` (0 failures
each) and `woods_playthrough` (0 failures, extraction won; it needs more than
the runner's 240 s limit in a real window). `verify_network.py --mode all
--players 2` passed and supplied the lobby image. **Not resolved:** in the
graphical run, `offline_playthrough` lost its scripted 60-minute route to the
stalker and the runner stopped there; the same test passes headless. No README
image comes from that test.

## 2026-10-17 — SpriteCook: items, camp, interiors, landmarks, textures, title

The user added 800 credits and asked to make everything look better while
keeping most in reserve. This pass spent **84 credits (7 images); 716 remain.**
Grids were used throughout, so each 12-credit image covered 9–16 assets.

- **Four 4×4 object grids:**
  - items: 16 pickups, also used as HUD belt icons;
  - camp objects: van, tent, campfire, locked-cache crate, generator, lamp post,
    notice board, picnic table, outhouse, canoe, woodpile, barrel, signpost,
    fence, gate, toolbox;
  - furniture: bunk, desk, locker, crates, workbench, mess table, stove,
    shower, basin, cot, bench, bookshelf, canoe rack and more;
  - landmarks: bell frame, well, cauldron, crypt, gravestones, altar,
    waterwheel, observatory, rail signal, column, shrine, hunter's blind, cave,
    watchtower, scrap pile.

  `tools/slice_spritecook_grid.gd` stores trimmed native sprites.
  `PixelArt.fit/draw_in/draw_standing` size them at runtime (palette-snapped,
  cached, never upscaled), so furniture keeps its collision boxes and objects
  stand on their footprints.
- **Seamless textures:** a 2×2 texture-mode test (grass, forest floor, trail,
  road) was checked by tiling each quadrant. Two needed a leftover divider line
  trimmed; otherwise they wrap. A 3×3 followed: floorboards, bath tiles, brown
  and green shingles, water, cobbles, bog mud, dead grass, flagstones.
  Per-building roof images (the original plan, about 108 credits) were not
  needed. The camp TileMap uses the materials as world-aligned 16 px sub-tile
  sources; the woods terrain, building floors and roofs sample them through
  `PixelArt.draw_material`.
- **Title:** one 384×216 illustration under the menu's fog and fireflies. The
  menu panel is now translucent so the lurking stalker shows through.
- Old procedural drawings remain as fallbacks if any file is missing.
- Decor without collision (notice board, picnic table, outhouse, toolbox) is
  only drawn where its footprint is clear of obstacles and roads.

**Verification:** `python3 tools/verify.py` 100/100 steps, no errors or warnings.
`verify_network.py --mode all --players 2`: 269 assertions, 0 failures. **Not verified:** a human look at normal night lighting (inspection
shots raise the ambient light), seam visibility at every zoom level, other
platforms.

## 2026-10-16 — SpriteCook creatures (all 16 species)

The user added credits (44). Spent as three Nano Banana 2.1 images (12 each) and
one Nano Banana 2 Lite (8), leaving 0. For each group, a 4×4 grid of the old
creature poses (columns = species, rows = down/up/right/left) was uploaded and
redrawn as an edit, with detailed per-species prompts from the monster guide:
- A: werewolf, Sasquatch, vampire, witch;
- B: Briar Revenant, Lantern Moth, Switchback Hound, Relay Jackal;
- C: Ration Moth, Lens Eater, Boiler Saint, Shutter Wraith;
- D (Lite): Bramble Seamstress, Last-Car Conductor, Stoneback Ram, Candle Grazer.

`tools/import_spritecook_creatures.gd` splits each grid into equal cells, scales
each species uniformly to fit 64×64 (0.85–1.0, never upscaled; palette-snapped
when scaled) and builds the 3-frame rows. Some side views came back facing the
wrong way; these were fixed per species:
- mirrored the right profile for the revenant, both moths, hound, Wraith and
  Conductor;
- swapped the rows for the jackal and ram.

The moths and Wraith hover-bob instead of stepping. `cryptid.gd` drops the old
scar, fur and orb overlays drawn over the sprite. Sheet sizes are unchanged
(192×256), so no gameplay code changed.

Asset IDs are added to `spritecook-assets.json`. Evidence: the in-game lineup
of all 16 in [art evidence](evidence/spritecook/README.md).

## 2026-10-16 — SpriteCook art pass (forest, survivors, stalker)

The user asked for an art upgrade with SpriteCook, most important images first,
within a limited image budget. The account had 40 credits; Nano Banana 2.1
costs 12 per 1K image, so three generations were affordable (4 credits left).
Priority by screen coverage: forest props, then the player's own survivors,
then the stalker.

1. **Forest props:** one 3×3 grid (`841427ac…`). Sliced by
   `tools/slice_spritecook_props.gd` into `pine_0/1/2`, `birch`, `shrub`,
   `boulder` and new `spruce`, `dead_tree`, `stump`. Native pixels, trees
   bottom-anchored on the existing 64×80 canvas. The woods renderer now cycles
   eight tree textures (pines dominate, a rare dead snag).
2. **Survivors:** a 6×4 pose grid of the old standing frames (one per role and
   direction) was uploaded and edited (`68dff824…`), keeping layout and colours.
   The figures came back about 28×55 against 24×32 frames.
   `tools/import_spritecook_survivors.gd` area-downscales them to 31 px,
   snaps each to its own palette with a crisp alpha cut, and builds 3-frame walk
   rows (a 1 px step-bob with alternating legs). A downscale trial was compared
   by eye before acceptance. The held-item marker was shrunk and moved to the
   new hands (hidden in back view).
3. **Stalker:** the same edit approach on a 2×2 pose grid (`3ae44181…`).
   Frames grow from 32×40 to **40×48** so it stands about 1.5× a survivor
   (shared 0.52 scale). `killer.gd` draws the new frames, drops the old
   belt/scratch overlays tailored to the old art, and lifts the stun stars and
   state marker above the taller head.

`spritecook-assets.json` records asset IDs and sha12 hashes only (no URLs or
tokens). Raw sheets are kept in `art_sources/spritecook/`.
`tools/build_pixel_art.py` now skips the SpriteCook-owned files unless run with
`--procedural`; a rebuild left every sprite byte-identical.

**Not changed:** the 16 creatures, terrain atlas, buildings and code-drawn props
(out of credits). **Not verified:** how the downscaled art reads to a human at
normal play speed in the dark, and other platforms.

## 2026-10-16 — Overhaul F4b-2: shortcut gates, vaultable fences; nine new sounds

**Barriers** (physics layer 8: survivors and creatures collide, sight and light
raycasts on layer 1 don't):
- **Shortcut gates.** For each optional region in [mill, orchard, observatory,
  rail, chapel], the shortest straight run of 5 cells or fewer to a road is
  linked and carved as a trail. A gate sits on its last link, kept only if it
  measures as a clean wall-to-wall bar and leaves the inner cell connected.
  Night 42 has observatory, rail yard and chapel gates. Gates are nav
  obstructions with a disabled NavigationLink2D; opening from the region side
  (E) disables the bar and enables the link for everyone. Measured at the
  Observatory: 1,436 px closed, 44 px open.
- **Fences.** Up to 40 on maze links (not roads, regions or gates; 900 px
  apart) where the detour is at least 8 cells. E vaults in 0.45 s with layer 8
  dropped mid-hop (220 px noise if sprinting, else 90 px). Creatures can't
  vault and path around.
- **Bug caught:** fences first checked connectivity one at a time, and two
  together sealed off map corners on seeds 99 and 76543 (navigation errors).
  Every barrier is now accepted only if its two sides stay connected with all
  earlier barriers closed. A whole-woods BFS test enforces this.
- Brush spots and piles are nudged out of the 14 px nav-seam strip
  (`CampMap.off_seam`) after one spot landed exactly on y=5112.

**Sounds.** The user added nine MP3s. They were already committed (my F4b-1
commit used `git add -A` and swept them in unintegrated); this entry integrates
and documents them:
- `screech_1`–`5`: calls for the ten newer creatures, which previously borrowed
  the revenant call; second species per file pitch-shifted;
- `radio_static` + `police_radio_talk`: a non-positional ranger-radio broadcast
  at each phase change (1 s static, then a 7 s faded chatter excerpt, a
  different one per phase), replacing the borrowed werewolf-howl stinger;
- `thud`: door slam, deeper door break-in, gate opening, vault landing;
- `wood_falling`: knock-overs and splintering door break-ins.

Prop sounds are inferred from replicated state, so the host and clients each
play them once.

Gains were set from a full-file decode (`afconvert` → PCM): RMS, peak and onset
per file. Creature calls are matched to the werewolf call's effective RMS
(about −29 dB). `screech_1`/`screech_3` begin at 1.0/2.4 s and `thud` at
0.25 s via a new manifest `start_seconds`. `wood_falling` and `thud` peaked at
full scale before trimming. The audio test now frees the 12-voice pool between
species: with real output, the long screeches correctly exhausted it.

Other test fixes: barrier positions within the 22 px reach; two physics frames
for the sound watcher to see a vault (`physics_frame` fires before nodes
update). One intermittent gate-open failure appeared once in a capture run and
not in 5 reruns. A diagnostic print remains in the test for any recurrence.

**Verification:** `python3 tools/verify.py` 93/93 steps, no errors or warnings
(new `barriers`: 32 headless / 34 graphical). Graphical `audio_polish` with real
output: 96 checks, all passing. `verify_network.py --mode all`: 2 peers 269 and
4 peers 455 assertions, all passing (gate replication included in the existing
hide/door assertion). Evidence: [barriers and audio](evidence/barriers_audio/README.md). Not
verified: human listening (levels were set from measurements, not ears),
human route feel, other platforms.

## 2026-10-16 — Overhaul F4b-1: rotating cache regions and the clue chain

- `RoundPlan._rotate_caches()` (separate RNG, `seed + 4242`) picks three of four
  directions, then one region per direction from `REGION_POOL` (N: village/
  observatory, E: bog/rail, S: graveyard/chapel, W: mill/orchard). The quarry
  is never used. `cache_spot()` keeps the original village/bog/graveyard spots;
  other regions use `position + (-80, 80)`.
- **Clue chain** (host-owned `level.clues`, replicated; 0 direction, 1 named, 2
  cache found):
  - the camp corkboard names fuel (Dusk message);
  - two `ranger_note` pickups per other part sit on the road cells nearest that
    part's region, at least 300 px apart;
  - reading a note names the region team-wide;
  - entering a region names its part, and marks the cache once the radio has
    revealed it.

  The pack uses the short sign names (DOME, RAILS...), radio messages follow
  the clue level, and skyline markers append known parts (`DOME · FUSE`).
- Rules `lnac-net-9`.

**Navigation seams.** While validating, a camp item became unreachable and
paths lost clearance where wall edges lay exactly on the 1,536 px nav chunk
seams. Each chunk is eroded by the 7 px agent radius at its edges. The F4a roads
put many woods wall edges on the old seams (75–83 per night, measured).
- A first 100 px shift moved a seam 4 px from a camp cabin wall.
- A half-chunk shift put one through Maintenance.

Final layout: seams at x=808 / y=504 (inside the camp's two main roads, which
buildings and trees never occupy). Neither is a multiple of 32, so no woods
wall can ever lie on a seam; a new test enforces this and fails on the old
layout. Seams also stay clear of the y=520 stalker patrol line (a seam at 520
put a test target in the off-mesh strip).

**Expedition bot.** Rotation sent night 42 to the orchard, village and rail
yard. The bot ran out of flares on the rail-yard return and was downed. It now
flash-stuns (Space) when cornered without flares, as a player would, and
survived three encounters. A later stall was a 1,180 px straight leg down the
east spoke, longer than the bot's fixed 900-frame waypoint budget. The budget
now scales with distance (1.6× walking time). In hindsight the earlier y=1920
stall was likely the same budget issue rather than the seam.

**Verification:** `python3 tools/verify.py` 91/91 steps, no errors or warnings
(new `rotation_clues`: 14 headless / 16 graphical; `road_network` 23/26 with
seam checks). `verify_network.py --mode all`: 2 peers 269 and 4 peers 455
assertions, all passing. One earlier 4-peer run had a single
`wait_client_movement` timeout that did not recur in the final run. Evidence:
[rotation/clues](evidence/rotation_clues/README.md). Not verified: human feel of
the clue chain, other platforms.

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
