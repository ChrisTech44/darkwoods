# Supplied sound assets

The user supplied the MP3 files in this folder for integration into the game on
16 October 2026. File names describe the intended ambience, footsteps, heartbeat,
music and creature cues. Local playback is the current implementation priority;
networked sound and proximity voice remain future acceptance gates.

Creator/source/license documents were not included with these files. Track them
as user-supplied assets, with redistribution provenance pending documentation;
do not label them original recordings or independently license-verified assets.
No microphone capture is implemented or needed for playback.

## Implemented offline cue mapping

The [manifest](manifest.json) records each actual file, stable cue ID, SHA-256,
duration, loop mode, bus, runtime gain and available provenance. Original MP3s
are unchanged. Godot duplicates stream resources before setting loop flags.

| Supplied file | Playback |
| --- | --- |
| `woods_background.mp3` | Forest/camp ambience, quieter indoors |
| `swamp_background.mp3` | Crossfades in around the witch bog |
| `campfire_crackling.mp3` | Positional campsite fire, fades with distance |
| `ominousBackgroundMusic.mp3` | Restrained round music, ducks under pursuit |
| `heartbeat_sound.mp3` | Fades in when stalker/cryptids see the player; fades out after target loss |
| `single_footstep.mp3` | Distance-based outdoor walking; quieter/lower stalker and cryptid steps |
| `footsteps_running_grass.mp3` | Outdoor sprint loop only during actual movement |
| `footsteps_walking_indoor.mp3` | Indoor movement loop, faster pitch when sprinting |
| `werewolf_howl.mp3` | Werewolf alert/nearby call |
| `bigfoot_growl.mp3` | Bigfoot alert/nearby call |
| `lanternmoth_screech.mp3` | Lantern moth alert/nearby call |
| `witch_cackle.mp3` | Witch alert/casting/nearby call |
| `revenant_screech.mp3` | Briar revenant alert/nearby call |
| `vampire_snarl_brief.mp3` | Vampire alert/nearby call |
| `screech_1.mp3` | Shutter Wraith call; Lens Eater at pitch 0.78. Starts at 1.0s (silent lead-in) |
| `screech_2.mp3` | Bramble Seamstress call; Candle Grazer at pitch 0.82 |
| `screech_3.mp3` | Boiler Saint call; Last-Car Conductor at pitch 0.80. Starts at 2.4s (silent lead-in) |
| `screech_4.mp3` | Switchback Hound call; Relay Jackal at pitch 0.80 |
| `screech_5.mp3` | Stoneback Ram call; Ration Moth at pitch 1.25 |
| `thud.mp3` | Door slam; deeper door break-in (with `wood_falling`); gate opening; fence-vault landing. Starts at 0.25s |
| `wood_falling.mp3` | Woodpile/deadfall knock-overs; splintering on door break-ins |
| `radio_static.mp3` | ~1s static burst opening each night-phase ranger radio broadcast (non-positional) |
| `police_radio_talk.mp3` | ~7s faded chatter excerpt after the static at each phase change; a different excerpt per phase |

The nine later files (added 16 October 2026, user-supplied, same provenance
status) were levelled from a full-file decode (`afconvert` → PCM). Creature
calls were matched to the werewolf call's effective RMS (about −29 dB after
gain), props sit lower, and silent lead-ins are skipped via the manifest's
`start_seconds`. Prop sounds are inferred from replicated door, knock-over, gate
and vault state, so the host and each client play them once, locally. The
radio replaced the earlier borrowed werewolf-howl phase stinger.

Monster calls have a shared per-source 8–14s cooldown, including witch casting,
so state changes do not stack loud voices. At most 12 positional one-shots play
at once. Seven round-owned loop channels fade smoothly; stopping, collision and
boarding stop movement sounds. Pause suspends playback; results stop it and
scene replacement frees all emitters. Menu has separate music/subdued woods channels, freed before entering the round.

The main menu and Esc pause panel provide saved Master/Effects/Ambience/Music controls; zero mutes. Voice
bus is reserved and inactive. AI hearing is independent of local playback/mute.
No microphone capture or microphone permission request exists in this build.

Initial gain staging uses measured file peaks/mean levels and a master limiter. The fire sub-bus compresses rare peaks and lifts quiet
crackles before passing through the Ambience control.
Loop seams and final comfort/balance require human listening; automated PCM
decode and loop/lifecycle checks are documented in the development log.
Windows/Linux, exported audio and two-client synchronized sound remain unverified.

Creature calls now start only within 160 pixels and follow their source, with
quadratic native distance attenuation. Enemy steps use 110 pixels. These local
limits do not change AI hearing. Menu knobs are accessed through Settings.

## 17 October 2026 sound pack

Twenty-seven more user-supplied files (provenance pending documentation, as
above). Three were edited, per the user's instructions in the file names or
to loop cleanly; everything else is unchanged and gain-balanced at runtime.

| File | Cue | Playback |
| --- | --- | --- |
| `thunder_clap.mp3` | `thunder` | 0.25–1.4 s after each storm lightning flash |
| `heavy_rain_loop.mp3` | `rain_heavy` | Storm downpour; quieter indoors. **Edited:** trailing 0.4 s silence trimmed (29.5 s) |
| `light_rain_loop.mp3` | `rain_light` | Rain-night drizzle |
| `car_start.mp3` | `car_start` | Van engine start (heard to 700 px) |
| `car_alarm.mp3` | `car_alarm` | Van alarm when the stalker steals a part (1,400 px); skips 1.8 s lead silence |
| `boat_engine_loop.mp3` | `boat_engine` | Positional outboard during the 25 s boat launch |
| `metal_clang.mp3` + `chain_rattle.mp3` | `metal_clang`, `chain_rattle` | Snare jaws and chain when a survivor is caught |
| `scary_bells_ringing.mp3` | `bells` | The Stalker's Gift bell (1,000 px) |
| `hunt_horn_single.mp3` | `hunt_horn` | The Hunt Begins |
| `fire_whoosh.mp3` / `fire_burning_loop.mp3` | `fire_whoosh`, `fire_loop` | Signal pyre ignition, then a positional blaze |
| `generator_sound_loop.mp3` | `generator` | Positional hum by Maintenance while camp has power |
| `door_creak.mp3` | `door_creak` | Opening a cabin door |
| `lock_rattle.mp3` | `lock_rattle` | Trying a locked cache without tools |
| `owl_hooting.mp3`, `wind_gust.mp3`, `random_eerie_sound.mp3` | `owl`, `wind`, `eerie` | Random woods ambience every 22–48 s |
| `wet_footsteps.mp3` | `wet_steps` | Footstep loop in the bog |
| `gravel_footsteps_loop.mp3` | `gravel_steps` | Footstep loop on roads. **Edited:** first 6 s of `dirt_gravel_footsteps_use_only_first_6_seconds_loop.mp3` |
| `fast_breathing_loop.mp3` | `breathing` | Held breath while hidden near danger; panting when exhausted. **Edited:** first half (5.5 s) of `fast_breaking_use_first_half_only_on_loop.mp3` |
| `chase_music.mp3` | `chase_music` | Music layer that swells while you are chased (off on Silent Night) |
| `monster_noise_6.mp3` | `monster_6` | Relay Jackal |
| `monster_noise_7_female.mp3` | `monster_7` | Bramble Seamstress |
| `monster_noise_8.mp3` | `monster_8` | Stoneback Ram; the Groundskeeper's growl |
| `monster_scream_9.mp3` | `monster_9` | Shutter Wraith |
| `monster_scream_10.mp3` | `monster_10` | Switchback Hound |

Every event sound is triggered from replicated world state, so all co-op peers
hear it, not only the host.
