# Sound review and recording list

18 October 2026. Scope: repository files, cue registry, source routing and two
headless cue-count diagnostics. No listening, mixing, real-microphone or network
audio acceptance is claimed. No new sound files or playback changes ship here.

**Implementation update (later on 18 October):** the user supplied 17 files. The
air horn, bear-trap duplicate, sneeze, dog bark/whine, camera charge/shutter,
train, squeaky toy, mud gurgle, lullaby, frog croak, giggle, survivor
hurt/grab/down, scissors and rescue helicopter are now wired (trimmed and
levelled; see the [audio README](../assets/audio/README.md#18-october-2026-sound-pack)).
Host creature/item cues now reach clients once through a snapshot sound log.
Still missing: whistle recording, thread snap, snore, noise-tin rattle,
flashlight/pickup/install/flare UI-feedback sounds, phase stingers, revive.
Mix balance remains unjudged by ear; two-machine playback was not tested.

## Reviewer's assessment

The atmosphere already has substantial coverage: woods/bog beds, campfire, rain,
thunder, footsteps, heartbeat, chase music, radios, doors, engine/pyre/generator
loops and creature calls. More ambience is not the first need. The gap is
**meaningful feedback**: important actions can affect AI or player state without
an identifiable audible consequence. Reused screeches and engines also make
otherwise different creatures sound mechanically similar.

An AI noise event (`level.loud_noise` / `hear_stimulus`) is not speaker playback.
The soundscape does not turn every AI hearing stimulus into a recording. Adding a
file alone will not create the missing trigger, and a local direct cue alone does
not prove all remote peers hear it once.

The [registry audit](evidence/world_review/audio_registry_audit.json) found **50
registered cues, zero missing referenced files and zero unregistered literal
playback calls in `scripts/`**. Dynamic cue maps were inspected separately. This
is not proof that every desired event has a sound, or that the mix is good.

## Existing wishlist, reconciled with code

The original 13 entries are in the
[asset wishlist](../assets/audio/README.md#wish-list-monster-revamp).
Every requested bespoke recording is still absent; some events have substitutes.

| Requested recording | Current implementation | Recording priority |
| --- | --- | --- |
| Slow and faster male “Row, Row, Row Your Boat” whistle | Synthesized `CampSong`, attached to both headline killers. Already audible by design; replace only if the recording improves character. | Medium |
| Big dog bark and friendly whine | Buster uses `monster_10` at different pitches. Friendly/hostile identity is weak. | High |
| Sneeze | Puffball sneeze produces AI noise in `ForestLevel._advance_effects`; no sneeze recording/playback. | High |
| High-pitched giggle | Imps use pitched `witch_cackle`. | Medium |
| Camera shutter and charging/flash whine | Paparazzo uses pitched `screech_4` and `metal_clang`. | High: warns a directed attack |
| Train bell and short steam whistle | Conductor uses pitched `bells` and `car_start`. | Medium |
| Squeaky toy footstep | Bear Hug uses high-pitched `footstep`. | Medium |
| Mud gurgle/suction | Bog Hands plays pitched `swamp` ambience as a one-shot. | Medium |
| Soft hymn/choir hum | Lullaby Saint plays low-pitched `bells`; the general creature call is also a screech. | High: its danger is supposed to be a song |
| Frog croak | Curse changes movement/voice effects, but no authored croak cue. | Low |
| Thread whip/snap | Seamstress uses pitched `monster_7`. | High: tether onset should be identifiable |
| Bear-trap snap | Generic `metal_clang`, currently requested twice on the host per activation. | High, after duplicate trigger fix |
| Air horn blast | `use_supply` stuns/alerts AI and prints “HOOOONK”; no playback cue. Diagnostic confirms zero accepted soundscape cues. | Highest |

Source: `scripts/ai/brains/*.gd`, `scripts/ai/camp_song.gd`,
`scripts/world/snares.gd`, `scripts/world/forest_level.gd`.

## Missing feedback beyond the wishlist

“Missing” here means no dedicated event playback was found, not that surrounding
ambience/music becomes silent. These need both authored/repurposed cues and
accepted-state triggers. Do not request all of them before fixing core feedback.

| Priority / set | Supply these sounds | Missing hook / practical value |
| --- | --- | --- |
| P0: survivor condition | Hit impact + short hurt gasp; downed fall/groan; revive completion; grab/struggle/release accents | Player damage/status and revive code lack dedicated cues. The hook grab has a chain rattle, but it does not cover this whole condition vocabulary. Players need immediate readable confirmation. |
| P0: light and inventory | Flashlight click, empty click, battery swap; flash burst; pickup, tool unlock/cutter snip, part installed | Lock failure already rattles, but successful pickup/install and light actions lack distinct completion sounds. Avoid playing a success cue on a rejected action. |
| P0: noisemakers | Air horn; noise-tin rattle; sneeze | All three have AI noise without their promised identifiable audio. The tin's three pulses are gameplay events, not a three-pulse recording to play once at the wrong time. |
| P1: fire and counters | Flare strike/ignition + small hiss loop; spray hiss; scissors snip | Pyre fire assets exist; ordinary thrown flares have light/particles but no linked ignition/hiss. Counter items mainly announce text. Short sounds communicate activation. |
| P1: threatened state | Camera whine/shutter, thread snap, dog bark/whine, hymn loop, sleep/snore | Existing creature substitutes cover some attacks. Snoring creates AI noise but has no snore recording. Distinct warnings matter more than extra roars. |
| P1: power and road | Fuse/breaker clunk, generator start/cough/stop, checkpoint alarm | Generator running loop exists. Restart noise and gate alarm hearing pulses lack their own real audible cues. Gate/vault movement already has a thud; don't buy a duplicate landing sound first. |
| P1: extraction | Lake splash wind-up/impact, relay transmission confirmation, rescue arrival/flyover, escape/defeat stingers | Boat engine exists but the Lake Thing's visual tells/hits have no dedicated splash. Rescue plane/helicopter/bridge extraction is presently mostly text/timers; choose a transport sound consistent with the actual presentation. |
| P2: place interactions | Village bell, well lid/rope, crypt scrape, cauldron gulp/bubble, lost-camper call, help call | `ForestSite.interact`, story camper and help actions chiefly announce/emit AI noise. The existing gift `bells` could cover village bell with a deliberate trigger; not every gap requires a new file. |
| P2: interface and drama | Focus/select/back, denied action, objective complete; Nightfall/Deep Night/Witching Hour stingers | No dedicated UI click/confirm family. Phase radio static/chatter already plays; titles need restrained complementary stingers, not another alarm over the radio. |

Evidence pointers: [world soundscape](../scripts/world/camp_soundscape.gd),
[player status](../scripts/actors/player.gd), [items/actions](../scripts/world/forest_level.gd),
[flare](../scripts/items/flare.gd), [noise tin](../scripts/items/noise_lure.gd),
[site interactions](../scripts/world/forest_site.gd),
[Lake Thing/escapes](../scripts/world/field_escapes.gd),
[radio rescue](../scripts/world/radio_rescue.gd),
[Saint/snoring](../scripts/ai/brains/boiler_saint.gd).

## First batch to add

For the largest improvement from a modest pack, supply these **twelve sets**:

1. `air_horn_blast` — one short unmistakable blast.
2. `noise_tin_rattle` — one dry rattle; the game repeats it for its three pulses.
3. `sneeze` — two or three natural variants.
4. `survivor_hurt`, `survivor_down`, `survivor_revive` — short distinct states.
5. `flashlight_click`, `flashlight_empty`, `battery_swap`, `flash_burst`.
6. `item_pickup`, `cutters_snip`, `part_installed`.
7. `flare_ignite`, `flare_hiss_loop`.
8. `camera_charge`, `camera_shutter`.
9. `dog_alarm_bark`, `dog_friendly_whine`.
10. `saint_hymn_loop`, `survivor_snore`.
11. `thread_snap`, `bear_trap_snap`.
12. `phase_nightfall`, `phase_deep_night`, `phase_witching_hour` — restrained 2–4s accents.

Each set may contain multiple files; this is not a twelve-file estimate. The
remaining table is a second batch. The existing synthesized whistle can stay
until a better character performance is available.

Deliver clean, dry mono effects with little/no leading silence; 2–3 variants help
frequent impacts/voices. Keep loops seamless and separate ignition/attack from
sustain/release. Source WAV at 44.1/48kHz is useful, but the current
`AudioManager.stream_for` explicitly expects `AudioStreamMP3`: provide MP3 runtime
copies or extend/test the loader before using WAV in the runtime manifest. Stereo
is suitable for non-positional music. Include the source/creator and usage rights
with the files, consistent with the existing manifest workflow.

## Playback defects and integration work

- **Confirmed duplicate:** one bear-trap trigger calls `metal_clang` directly in
  `Snares.advance`, then the shared snare state edge in `CampSoundscape._events`
  calls `metal_clang` again plus `chain_rattle`. Headless diagnostic returned
  `metal_clang: 2`, `chain_rattle: 1` for one activation. Pick one authoritative
  accepted event / replicated edge, not two local trigger paths.
- **Confirmed silent noisemaker:** successful air-horn use returned an empty
  accepted-cue map. Neither the registered cue list nor that action has a horn
  recording. This is missing playback, not a missing file import.
- **Creature-specific cues need remote verification:** brain `cue()` calls run
  with host AI, while replicas infer general creature calls from local state.
  An exact remote bark/shutter/camera/thread event is not established by a
  generic nearby roar. Wire/verify those transitions on both peers once.
- Repeatedly pitching the same scream does not reliably teach different counters.
  Reserve clear signatures for the most actionable threats. Ambient owl sounds
  also share a sample with the real owl; assess whether that confusion feels
  eerie or unfair in a listening playtest before changing it.
- Current audio README/design contain old ranges, cue assignments and “voice not
  implemented” paragraphs. This review and the current source distinguish
  implementation from real-device acceptance; old prose is not a sound inventory.

Reproduction: [diagnostic output](evidence/world_review/sound_feedback.log), from
`godot --headless --path . --audio-driver Dummy --script res://tools/audit_sound_feedback.gd`.
Accepted-cue counts show routing only. No headphone listening, mix balance or
cross-machine exactly-once acceptance was performed in this review.
