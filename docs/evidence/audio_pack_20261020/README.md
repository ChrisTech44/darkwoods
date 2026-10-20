# 20 October user audio pack

Twelve user uploads produce fifteen trimmed/levelled runtime cues: six replace
synthesis and nine add dedicated feedback. Originals and their SHA-256 hashes
are preserved in [the source pack](../../../art_sources/audio/2026-10-20/processing.json).
The [manifest](../../../assets/audio/manifest.json) records mono channel selection,
trims, gain, loop settings, provenance and post-encode measurements.
Rebuild using `python3 tools/process_october_audio.py` (ffmpeg, Python stdlib).

All processed peaks are below −6 dBFS; runtime gains give additional headroom.
Mean levels vary by transient/sustain and crest factor; quiet breathing is raised
22 dB and the dense mega horn reduced 14.4 dB. No claim that input distortion was
restored. Speech gaps and breath cycles are preserved. Loop joins use a 100ms
circular crossfade; native decoder wrap is checked separately from listening.

| Runtime cue | Source section (s) | Duration | Gain | Decoded peak | Decoded mean |
| --- | --- | --- | --- | --- | --- |
| `lifeguard_shout` | 0–1.78 | 1.780s | -3.4dB | -6.4dBFS | -25.7dBFS |
| `nightlight_scream` | 0.045–1.4 | 1.355s | -5.0dB | -8.4dBFS | -22.4dBFS |
| `nobody_breathing` | 2.65–13.25 | 10.500s | +22.0dB | -8.4dBFS | -29.4dBFS |
| `vulture_squawk` | 0.035–1.227 | 1.192s | -1.9dB | -10.9dBFS | -23.4dBFS |
| `magician_drumroll` | 0.065–2.015 | 1.500s | -0.5dB | -8.3dBFS | -24.4dBFS |
| `magician_tada` | 2.015–4.55 | 2.535s | -4.6dB | -6.5dBFS | -25.9dBFS |
| `noise_tin_rattle` | 0.36–2.15 | 1.790s | +2.7dB | -6.4dBFS | -33.1dBFS |
| `village_bell` | 0.055–3.15 | 3.095s | -0.8dB | -6.4dBFS | -28.4dBFS |
| `flare_ignite` | 0.18–2.65 | 2.470s | -2.5dB | -6.4dBFS | -36.7dBFS |
| `flare_hiss` | 2.75–10.75 | 7.900s | +12.6dB | -12.7dBFS | -28.4dBFS |
| `flashlight_on` | 0.08–0.245 | 0.165s | +6.5dB | -6.5dBFS | -37.4dBFS |
| `flashlight_off` | 0.33–0.49 | 0.160s | +5.9dB | -6.4dBFS | -38.3dBFS |
| `snore` | 0.14–1.64 | 1.400s | -4.4dB | -16.4dBFS | -27.4dBFS |
| `water_splash` | 0–0.89 | 0.890s | -4.6dB | -6.5dBFS | -32.7dBFS |
| `huntmaster_horn` | 0–4.22 | 4.220s | -14.4dB | -14.6dBFS | -23.4dBFS |

Magician: the first section is tempo-fitted without changing pitch to the existing
1.5s windup; the ending plays only after a valid swap. Huntmaster: the entire
4.22s user mega horn replaces the synthesized blast, including Christian's copy;
its 2s windup, haste and cooldown remain unchanged. The separately synthesized
inhale remains. Vulture retains the natural two-call phrase.

Flare: the onset/strike section is a single ignition cue; its steady tail becomes
a separate hiss loop following each replicated live flare. The two transients
in the flashlight file become separate on/off clicks. Rejected empty, cursed
or forced-on toggles produce no success click. Offline and online toggles now
share the same accepted-action path; this also prevents offline flicking against
the forced-on effect. The pre-existing light locks remain in force.

Tin: one rattle per existing AI pulse, three pulses total. Village bell and lake
impact now broadcast their dedicated cues; a flare-cancelled lake attack has no
impact splash. Sleep state starts a following snore loop, cleared on waking,
death, removal or round stop. These playback additions add no AI noise events.
Lifeguard speech accompanies a quieter whistle; both real and copied signatures
use the recording. Client snapshot replay does not duplicate host events.

Inspected processed waveforms (square-root amplitude display; not a listening
substitute): [breathing](nobody_breathing_processed.png),
[mega horn](huntmaster_horn_processed.png), [drumroll](magician_drumroll_processed.png),
[flare hiss](flare_hiss_processed.png). [Executed results](results.json):
35 event/lifecycle assertions, 18 native PCM/loop assertions, 122 real ENet checks,
153 dedicated/four-client checks, plus existing audio, survivor and creature
regressions. Required import/startup and diff checks are clean. Microphones off.
No human listening-quality, Internet, package or other-platform acceptance claim.


The local ignored gallery's seventeen recent monster/copy clips were refreshed
from audio-integration commit `9c01ce0` with the supplied recordings. H.264/AAC,
full decoding, nonzero audio, matching outcome observations and all 64 media paths
verify. Original staging/lighting labels remain. The audio rules suite also passes
164 checks with the isolated `--audio-test` settings profile. Local MP4s remain
outside Git; no human listening acceptance is implied by these checks.
