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

Monster calls have a shared per-source 8–14s cooldown, including witch casting,
so state changes do not stack loud voices. At most 12 positional one-shots play
at once. Seven round-owned loop channels fade smoothly; stopping, collision and
boarding stop movement sounds. Pause suspends playback; results stop it and
scene replacement frees all emitters. Menu has no round playback.

Esc opens saved Master/Effects/Ambience/Music volume controls; zero mutes. Voice
bus is reserved and inactive. AI hearing is independent of local playback/mute.
No microphone capture or microphone permission request exists in this build.

Initial gain staging uses measured file peaks/mean levels and a master limiter. The fire sub-bus compresses rare peaks and lifts quiet
crackles before passing through the Ambience control.
Loop seams and final comfort/balance require human listening; automated PCM
decode and loop/lifecycle checks are documented in the development log.
Windows/Linux, exported audio and two-client synchronized sound remain unverified.
