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
