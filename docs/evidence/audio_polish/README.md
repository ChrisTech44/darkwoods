# Offline audio and camp polish evidence

All captures/logs come from Godot 4.7.2 on macOS arm64.
`python3 tools/verify.py --graphical` runs import/startup, script parses, nine
headless suites and nine graphical suites, including active camp/woods rounds.

`audio_polish.log` is the no-device path. `graphical_audio.log` uses Dummy audio
output with actual MP3 decoding, native mixer buses/effects and captured nonzero
gain-staged PCM. It also seeks across the end of each of seven looped streams.
These are automated playback/cleanup checks, not human listening evidence.
Other graphical gameplay suites use the normal platform audio driver.

The pause mixer capture shows the actual 384×216 viewport. Camp layout overviews
use an inspection camera and brighter ambient light. Normal gameplay lighting
is shown by the campsite/woods views. Isolated mechanics/audio checks deliberately
place actors; complete camp and woods escape suites use production input/AI rules.

Windows/Linux, packaged audio, two-client synchronized audio, microphone/voice,
final listening/seam comfort and cross-platform output devices are unverified.
The supplied sound files have source/license documentation pending, as recorded
in the asset manifest. DOCX requirements/OOXML checks pass; visual document QA
cannot run because the renderer dependencies and LibreOffice are unavailable.
